import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

// Everything the face shows, read from the watch. Sensors are read at most once a minute
// (or immediately on wrist raise); missing or stale values stay null and draw as "--".
class Model {
    // time
    var hour as Number = 0;
    var min as Number = 0;
    var sec as Number = 0;
    var is24 as Boolean = true;
    var year as Number = 2026;
    var month as Number = 1;
    var day as Number = 1;
    var weekday as Number = 1; // 1 = Sunday
    var termText as String or Null = null;
    var lunarText as String or Null = null;
    // sky
    var sunrise as Number = 6 * 3600;
    var sunset as Number = 18 * 3600;
    var weatherClass as Number = 0; // 0 clear 1 partly 2 cloudy 3 rain 4 snow 5 fog 6 storm
    var temp as Number or Null = null;
    // body & device
    var hr as Number or Null = null;
    var steps as Number or Null = null;
    var stepGoal as Number or Null = null;
    var moveBar as Number = 0;
    var bodyBattery as Number or Null = null;
    var calories as Number or Null = null;
    var stress as Number or Null = null;
    var altitude as Number or Null = null; // metres
    var stressLimit as Number = 70;        // volcano above this stress level
    var batteryLimit as Number = 20;       // lightning at or below this battery level
    var battery as Number = 0;
    var charging as Boolean = false;
    var notifications as Number = 0;
    var phone as Boolean = true;
    // settings
    var sky as Number = 0;
    var weatherFx as Boolean = true;
    var motion as Number = 0; // 0 rich 1 simple 2 off
    var festivals as Boolean = true; // festival skies on their days
    var accent as Number = 0;        // 0 amber 1 teal 2 sakura 3 snow
    // bumps whenever something that changes the static palette changes
    var revision as Number = 0;
    // demo build only (see Demo.mc)
    var demoAod as Boolean = false;
    var demoIndex as Number = -1;

    hidden var lastRead as Number = -100000;
    hidden var lastDay as Number = -1;
    hidden var lastMinute as Number = -1;

    function initialize() {
        var cached = Application.Storage.getValue("sun");
        if (cached instanceof Array && cached.size() == 2) {
            sunrise = cached[0] as Number;
            sunset = cached[1] as Number;
        }
    }

    function refresh(force as Boolean) as Void {
        var clock = System.getClockTime();
        hour = clock.hour;
        min = clock.min;
        sec = clock.sec;
        var ds = System.getDeviceSettings();
        is24 = ds.is24Hour;
        var now = Time.now().value();
        var minuteKey = hour * 60 + min;
        if (minuteKey != lastMinute) { lastMinute = minuteKey; revision += 1; }
        if (!force && now - lastRead < 60) { return; }
        lastRead = now;
        revision += 1;

        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        year = info.year;
        month = info.month as Number;
        day = info.day;
        weekday = info.day_of_week as Number;
        if (day != lastDay) {
            lastDay = day;
            termText = Cal.term(year, month, day);
            lunarText = Cal.lunarText(year, month, day);
        }

        sky = setting("Sky", 0);
        motion = setting("Motion", 0);
        stressLimit = setting("StressThreshold", 70);
        accent = setting("Accent", 0);
        var fe = Application.Properties.getValue("Festivals");
        festivals = fe instanceof Boolean ? fe : true;
        batteryLimit = setting("LowBattery", 20);
        var fx = Application.Properties.getValue("WeatherFx");
        weatherFx = fx instanceof Boolean ? fx : true;

        var stats = System.getSystemStats();
        battery = (stats.battery + 0.5).toNumber();
        charging = stats has :charging ? stats.charging : false;
        notifications = ds.notificationCount;
        phone = ds.phoneConnected;

        readActivity(now);
        readWeather(now, ds);
        readSun();
    }

    hidden function setting(key as String, fallback as Number) as Number {
        var v = Application.Properties.getValue(key);
        return v instanceof Number ? v : fallback;
    }

    hidden function readActivity(now as Number) as Void {
        var a = ActivityMonitor.getInfo();
        steps = a.steps;
        stepGoal = a.stepGoal;
        moveBar = a.moveBarLevel != null ? a.moveBarLevel as Number : 0;
        calories = a.calories;

        hr = null;
        var act = Activity.getActivityInfo();
        if (act != null && act.currentHeartRate != null) {
            hr = act.currentHeartRate;
        } else {
            try {
                var h = SensorHistory.getHeartRateHistory({:period => 1}).next();
                if (h != null && h.data != null && h.when != null && now - h.when.value() < 300) { hr = h.data.toNumber(); }
            } catch (e) { }
        }

        stress = complicationNumber(Complications.COMPLICATION_TYPE_STRESS);
        if (stress == null && SensorHistory has :getStressHistory) {
            try {
                var st = SensorHistory.getStressHistory({:period => 1}).next();
                if (st != null && st.data != null && st.when != null && now - st.when.value() < 900) { stress = st.data.toNumber(); }
            } catch (e) { }
        }
        altitude = complicationNumber(Complications.COMPLICATION_TYPE_ALTITUDE);
        if (altitude == null) {
            try {
                var el = SensorHistory.getElevationHistory({:period => 1}).next();
                if (el != null && el.data != null && el.when != null && now - el.when.value() < 900) { altitude = el.data.toNumber(); }
            } catch (e) { }
        }

        bodyBattery = complicationNumber(Complications.COMPLICATION_TYPE_BODY_BATTERY);
        if (bodyBattery == null && SensorHistory has :getBodyBatteryHistory) {
            try {
                var b = SensorHistory.getBodyBatteryHistory({:period => 1}).next();
                if (b != null && b.data != null && b.when != null && now - b.when.value() < 3600) { bodyBattery = b.data.toNumber(); }
            } catch (e) { }
        }
    }

    hidden function readWeather(now as Number, ds as System.DeviceSettings) as Void {
        temp = null;
        weatherClass = 0;
        try {
            var w = Weather.getCurrentConditions();
            if (w == null || w.observationTime == null || now - w.observationTime.value() > 3 * 3600) { return; }
            weatherClass = classify(w.condition);
            if (w.temperature != null) {
                var c = w.temperature.toFloat();
                if (ds.temperatureUnits == System.UNIT_STATUTE) { c = c * 9 / 5 + 32; }
                temp = (c < 0 ? c - 0.5 : c + 0.5).toNumber();
            }
        } catch (e) { }
    }

    // Garmin conditions -> the seven scenes the landscape can paint
    static function classify(c as Number or Null) as Number {
        if (c == null) { return 0; }
        if ([Weather.CONDITION_THUNDERSTORMS, Weather.CONDITION_SCATTERED_THUNDERSTORMS, Weather.CONDITION_TORNADO,
             Weather.CONDITION_HURRICANE, Weather.CONDITION_TROPICAL_STORM, Weather.CONDITION_SQUALL].indexOf(c) >= 0) { return 6; }
        if ([Weather.CONDITION_SNOW, Weather.CONDITION_LIGHT_SNOW, Weather.CONDITION_HEAVY_SNOW, Weather.CONDITION_FLURRIES,
             Weather.CONDITION_WINTRY_MIX, Weather.CONDITION_RAIN_SNOW, Weather.CONDITION_LIGHT_RAIN_SNOW,
             Weather.CONDITION_HEAVY_RAIN_SNOW, Weather.CONDITION_SLEET, Weather.CONDITION_ICE_SNOW, Weather.CONDITION_HAIL,
             Weather.CONDITION_ICE, Weather.CONDITION_FREEZING_RAIN].indexOf(c) >= 0) { return 4; }
        if ([Weather.CONDITION_RAIN, Weather.CONDITION_LIGHT_RAIN, Weather.CONDITION_HEAVY_RAIN, Weather.CONDITION_SHOWERS,
             Weather.CONDITION_LIGHT_SHOWERS, Weather.CONDITION_HEAVY_SHOWERS, Weather.CONDITION_SCATTERED_SHOWERS,
             Weather.CONDITION_DRIZZLE, Weather.CONDITION_UNKNOWN_PRECIPITATION].indexOf(c) >= 0) { return 3; }
        if ([Weather.CONDITION_FOG, Weather.CONDITION_MIST, Weather.CONDITION_HAZY, Weather.CONDITION_HAZE,
             Weather.CONDITION_DUST, Weather.CONDITION_SMOKE, Weather.CONDITION_SAND, Weather.CONDITION_SANDSTORM,
             Weather.CONDITION_VOLCANIC_ASH].indexOf(c) >= 0) { return 5; }
        if ([Weather.CONDITION_CLOUDY, Weather.CONDITION_MOSTLY_CLOUDY, Weather.CONDITION_CHANCE_OF_SHOWERS,
             Weather.CONDITION_CHANCE_OF_THUNDERSTORMS, Weather.CONDITION_CHANCE_OF_SNOW, Weather.CONDITION_CHANCE_OF_RAIN_SNOW,
             Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN, Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW,
             Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW].indexOf(c) >= 0) { return 2; }
        if ([Weather.CONDITION_PARTLY_CLOUDY, Weather.CONDITION_THIN_CLOUDS, Weather.CONDITION_WINDY].indexOf(c) >= 0) { return 1; }
        return 0;
    }

    // sunrise / sunset in seconds since local midnight; the system computes them from the last GPS fix
    hidden function readSun() as Void {
        var rise = complicationNumber(Complications.COMPLICATION_TYPE_SUNRISE);
        var set = complicationNumber(Complications.COMPLICATION_TYPE_SUNSET);
        if (rise != null && set != null && set > rise) {
            if (rise != sunrise || set != sunset) {
                sunrise = rise;
                sunset = set;
                Application.Storage.setValue("sun", [rise, set]);
            }
        }
    }

    hidden function complicationNumber(type as Complications.Type) as Number or Null {
        if (!(Toybox has :Complications)) { return null; }
        try {
            var c = Complications.getComplication(new Complications.Id(type));
            if (c != null && c.value != null) {
                if (c.value instanceof Number) { return c.value as Number; }
                if (c.value instanceof Float) { return (c.value as Float).toNumber(); }
            }
        } catch (e) { }
        return null;
    }
}
