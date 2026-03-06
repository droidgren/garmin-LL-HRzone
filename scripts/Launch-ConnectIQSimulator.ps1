[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,
    [string]$ProjectPath = (Join-Path $PSScriptRoot "..\LastLapHRZone"),
    [string]$ConfigPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ConfigRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,
        [Parameter(Mandatory = $true)]
        [string]$BaseDirectory
    )

    if ([IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }

    return (Join-Path $BaseDirectory $PathValue)
}

$exitCode = 0
$didPushLocation = $false

try {
    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        throw "Device id is required."
    }

    $resolvedProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $ConfigPath = Join-Path $resolvedProjectPath ".vscode\ciq.local.json"
    }

    $resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
    $configBaseDir = Split-Path -Parent $resolvedConfigPath

    $cfg = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace($cfg.sdkHome)) {
        throw "Missing 'sdkHome' in $resolvedConfigPath"
    }

    if ([string]::IsNullOrWhiteSpace($cfg.devKey)) {
        throw "Missing 'devKey' in $resolvedConfigPath"
    }

    $sdkHome = Resolve-ConfigRelativePath -PathValue $cfg.sdkHome -BaseDirectory $configBaseDir
    $developerKeyPath = Resolve-ConfigRelativePath -PathValue $cfg.devKey -BaseDirectory $configBaseDir

    $monkeycPath = Join-Path $sdkHome "bin\monkeyc.bat"
    $monkeydoPath = Join-Path $sdkHome "bin\monkeydo.bat"
    $simulatorPath = Join-Path $sdkHome "bin\simulator.exe"

    if (-not (Test-Path -LiteralPath $monkeycPath)) {
        throw "monkeyc.bat not found under $sdkHome\bin"
    }

    if (-not (Test-Path -LiteralPath $monkeydoPath)) {
        throw "monkeydo.bat not found under $sdkHome\bin"
    }

    if (-not (Test-Path -LiteralPath $simulatorPath)) {
        throw "simulator.exe not found under $sdkHome\bin"
    }

    if (-not (Test-Path -LiteralPath $developerKeyPath)) {
        throw "Developer key not found: $developerKeyPath"
    }

    Push-Location $resolvedProjectPath
    $didPushLocation = $true

    $prgFile = Join-Path ".\bin" ("sim-{0}.prg" -f $DeviceId)

    & $monkeycPath -f monkey.jungle -o $prgFile -d $DeviceId -w -y $developerKeyPath
    if ($LASTEXITCODE -ne 0) {
        $exitCode = $LASTEXITCODE
        throw "monkeyc failed with exit code $exitCode"
    }

    $prgFile = (Resolve-Path -LiteralPath $prgFile).Path
    $settingsFile = $prgFile -replace '\.prg$', '-settings.json'

    if (-not (Get-Process -Name simulator -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $simulatorPath
        Start-Sleep -Seconds 4
    }

    if (Test-Path -LiteralPath $settingsFile) {
        $settingsArg = "{0};{1}" -f $settingsFile, [IO.Path]::GetFileName($settingsFile)
        & $monkeydoPath $prgFile $DeviceId /a $settingsArg
    }
    else {
        Write-Warning "Settings metadata file not found: $settingsFile"
        & $monkeydoPath $prgFile $DeviceId
    }

    if ($LASTEXITCODE -ne 0) {
        $exitCode = $LASTEXITCODE
        throw "monkeydo failed with exit code $exitCode"
    }
}
catch {
    if ($exitCode -eq 0) {
        $exitCode = 1
    }

    Write-Error $_
}
finally {
    if ($didPushLocation) {
        Pop-Location
    }
}

exit $exitCode
