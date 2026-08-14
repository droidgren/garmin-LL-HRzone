import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.UserProfile;
import Toybox.WatchUi;

class LastLapHRZoneView extends WatchUi.DataField {

    // Accumulators for current lap HR data
    hidden var mCurrentLapHRSum as Number = 0;
    hidden var mCurrentLapHRSamples as Number = 0;

    // The computed average HR zone for the last completed lap
    hidden var mLastLapAvgZone as Float or Null = null;
    hidden var mDisplayText as String = "--";

    function initialize() {
        DataField.initialize();
    }

    // Called when the user presses the lap button (manual or auto-lap)
    function onTimerLap() as Void {
        if (mCurrentLapHRSamples > 0) {
            var avgHR = mCurrentLapHRSum.toFloat() / mCurrentLapHRSamples;
            mLastLapAvgZone = computeHRZone(avgHR);
            mDisplayText = (mLastLapAvgZone as Float).format("%.1f");
        }
        // Reset accumulators for the new lap
        mCurrentLapHRSum = 0;
        mCurrentLapHRSamples = 0;
    }

    // Zone boundaries for the sport the current activity uses, so the values match
    // Garmin's native HR zone field instead of always using the generic profile.
    hidden function getActiveHeartRateZones() as Array<Number> or Null {
        var zones = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
        if (zones == null || zones.size() < 2) {
            // Sport has no dedicated zones configured
            zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        }

        return zones;
    }

    // Calculate the decimal HR zone for a given average heart rate.
    // Returns a float like 3.4 meaning "40% through zone 3". Zone n spans [n.0, n+1.0),
    // so a 5 zone profile tops out at 6.0 just like the native field.
    hidden function computeHRZone(hr as Float) as Float {
        var zones = getActiveHeartRateZones();
        if (zones == null || zones.size() < 2) {
            return 0.0f;
        }

        var numZones = zones.size() - 1;
        var lowest = zones[0].toFloat();
        var highest = zones[numZones].toFloat();

        // At or above the top of the highest zone: Garmin's native field caps here
        if (hr >= highest) {
            return (numZones + 1).toFloat();
        }

        // Below zone 1: proportional value between 0 and 1
        if (hr < lowest) {
            if (lowest > 0) {
                return hr / lowest;
            }
            return 0.0f;
        }

        // Walk down from the top so a collapsed zone cannot trap the value
        for (var i = numZones - 1; i >= 0; i--) {
            var zoneLow = zones[i].toFloat();
            if (hr >= zoneLow) {
                var zoneHigh = zones[i + 1].toFloat();
                if (zoneHigh > zoneLow) {
                    var fraction = (hr - zoneLow) / (zoneHigh - zoneLow);
                    return (i + 1) + fraction;
                }
                return (i + 1).toFloat();
            }
        }

        return 0.0f;
    }

    // Called once per second during an activity
    function compute(info as Activity.Info) as Void {
        // Accumulate HR samples for the current lap
        if (info has :currentHeartRate && info.currentHeartRate != null) {
            mCurrentLapHRSum += info.currentHeartRate as Number;
            mCurrentLapHRSamples++;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var backgroundColor = getBackgroundColor();
        var defaultTextColor = getDefaultTextColor(backgroundColor);

        dc.setColor(defaultTextColor, backgroundColor);
        dc.clear();

        var valueColor = defaultTextColor;
        if (isZoneColorEnabled() && mLastLapAvgZone != null) {
            valueColor = getZoneColor(mLastLapAvgZone as Float, backgroundColor);
        }

        var width = dc.getWidth();
        var height = dc.getHeight();
        var showLabel = (height >= 40) && isHeaderTextEnabled();
        var labelFont = Graphics.FONT_XTINY;
        var valueFont = getValueFont(height);
        var labelHeight = showLabel ? dc.getFontHeight(labelFont) : 0;
        var valueY = showLabel ? ((height + labelHeight) / 2) : (height / 2);

        if (showLabel) {
            dc.setColor(defaultTextColor, backgroundColor);
            dc.drawText(width / 2, 0, labelFont, "LL HRZ", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(valueColor, backgroundColor);
        dc.drawText(width / 2, valueY, valueFont, mDisplayText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Reset everything when the timer is reset
    function onTimerReset() as Void {
        mCurrentLapHRSum = 0;
        mCurrentLapHRSamples = 0;
        mLastLapAvgZone = null;
        mDisplayText = "--";
    }

    hidden function getValueFont(fieldHeight as Number) as Graphics.FontType {
        if (fieldHeight >= 84) {
            return Graphics.FONT_LARGE;
        } else if (fieldHeight >= 56) {
            return Graphics.FONT_MEDIUM;
        }

        return Graphics.FONT_SMALL;
    }

    hidden function isZoneColorEnabled() as Boolean {
        try {
            var value = Application.Properties.getValue("zone_color_digits");
            if (value != null) {
                return value as Boolean;
            }
        } catch (e) {
        }

        return true;
    }

    hidden function isHeaderTextEnabled() as Boolean {
        try {
            var value = Application.Properties.getValue("show_header_text");
            if (value != null) {
                return value as Boolean;
            }
        } catch (e) {
        }

        return true;
    }

    hidden function getDefaultTextColor(backgroundColor as Graphics.ColorType) as Graphics.ColorType {
        if (backgroundColor == Graphics.COLOR_BLACK) {
            return Graphics.COLOR_WHITE;
        }

        return Graphics.COLOR_BLACK;
    }

    // Garmin-style zones: 1 gray, 2 blue, 3 green, 4 orange, 5 red
    hidden function getZoneColor(zone as Float, backgroundColor as Graphics.ColorType) as Graphics.ColorType {
        if (zone < 2.0f) {
            return (backgroundColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY;
        } else if (zone < 3.0f) {
            return Graphics.COLOR_BLUE;
        } else if (zone < 4.0f) {
            return Graphics.COLOR_GREEN;
        } else if (zone < 5.0f) {
            return Graphics.COLOR_ORANGE;
        }

        return Graphics.COLOR_RED;
    }

}