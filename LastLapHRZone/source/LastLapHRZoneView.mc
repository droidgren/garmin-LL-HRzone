import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.UserProfile;

class LastLapHRZoneView extends WatchUi.SimpleDataField {

    // Accumulators for current lap HR data
    hidden var mCurrentLapHRSum as Number = 0;
    hidden var mCurrentLapHRSamples as Number = 0;

    // The computed average HR zone for the last completed lap
    hidden var mLastLapAvgZone as Float or Null = null;

    function initialize() {
        SimpleDataField.initialize();
        label = "LL HR Zone";
    }

    // Called when the user presses the lap button (manual or auto-lap)
    function onTimerLap() as Void {
        if (mCurrentLapHRSamples > 0) {
            var avgHR = mCurrentLapHRSum.toFloat() / mCurrentLapHRSamples;
            mLastLapAvgZone = computeHRZone(avgHR);
        }
        // Reset accumulators for the new lap
        mCurrentLapHRSum = 0;
        mCurrentLapHRSamples = 0;
    }

    // Calculate the decimal HR zone for a given average heart rate.
    // Returns a float like 3.4 meaning "40% through zone 3".
    hidden function computeHRZone(hr as Float) as Float {
        var zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        if (zones == null || zones.size() < 2) {
            return 0.0f;
        }

        var numZones = zones.size() - 1;

        // Below zone 1
        if (hr < zones[0]) {
            // Return a proportional value between 0 and 1
            if (zones[0] > 0) {
                return hr / zones[0].toFloat();
            }
            return 0.0f;
        }

        // Find the zone the average HR falls into
        for (var i = 0; i < numZones; i++) {
            var zoneLow = zones[i].toFloat();
            var zoneHigh = zones[i + 1].toFloat();
            if (hr >= zoneLow && hr < zoneHigh) {
                var fraction = (hr - zoneLow) / (zoneHigh - zoneLow);
                return (i + 1) + fraction;
            }
        }

        // At or above the top of the highest zone
        return numZones.toFloat();
    }

    // Called once per second during an activity
    function compute(info as Activity.Info) as Numeric or Duration or String or Null {
        // Accumulate HR samples for the current lap
        if (info has :currentHeartRate && info.currentHeartRate != null) {
            mCurrentLapHRSum += info.currentHeartRate as Number;
            mCurrentLapHRSamples++;
        }

        // Display the last completed lap's average HR zone
        if (mLastLapAvgZone != null) {
            return (mLastLapAvgZone as Float).format("%.1f");
        }

        return "--";
    }

    // Reset everything when the timer is reset
    function onTimerReset() as Void {
        mCurrentLapHRSum = 0;
        mCurrentLapHRSamples = 0;
        mLastLapAvgZone = null;
    }

}