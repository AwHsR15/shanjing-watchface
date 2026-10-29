import Toybox.Lang;
import Toybox.System;

// Demo build only (demo.jungle): cycles through preset scenes so the simulator can be
// screen-captured. The release build compiles the empty version below.
(:demo)
function demoApply(m as Model) as Void {
    // hour, min, weather, steps, battery, charging, body battery, notifications, move bar, always-on, stress, month, day, weekday, temp[, year]
    var presets = [
        [10, 38, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 10, 23, 6, 16],
        [17, 2, 1, 6842, 82, 0, 72, 0, 0, 0, 31, 10, 23, 6, 16],
        [21, 40, 0, 6842, 82, 0, 72, 2, 0, 0, 31, 10, 23, 6, 9],
        [14, 10, 1, 11204, 82, 0, 72, 0, 0, 0, 31, 10, 23, 6, 16],
        [22, 5, 0, 10432, 82, 0, 60, 0, 0, 0, 31, 10, 23, 6, 8],
        [13, 20, 0, 6842, 82, 0, 72, 0, 2, 0, 86, 10, 23, 6, 16],
        [15, 45, 6, 6842, 12, 0, 18, 0, 0, 0, 31, 10, 23, 6, 14],
        [9, 15, 0, 3120, 82, 0, 80, 0, 0, 0, 31, 4, 12, 1, 15],
        [13, 40, 1, 9020, 82, 0, 66, 0, 0, 0, 31, 7, 18, 7, 31],
        [22, 30, 0, 6842, 82, 0, 70, 0, 0, 0, 31, 1, 8, 5, -6],
        [20, 18, 0, 6842, 82, 0, 70, 0, 0, 0, 31, 2, 17, 3, 2],
        [19, 50, 0, 6842, 82, 0, 70, 0, 0, 0, 31, 3, 3, 3, 8],
        [20, 30, 0, 6842, 82, 0, 70, 0, 0, 0, 31, 9, 25, 6, 18],
        [18, 40, 1, 6842, 82, 0, 70, 1, 0, 0, 31, 12, 24, 5, -2],
        [19, 31, 0, 6842, 82, 0, 70, 0, 0, 0, 31, 10, 31, 7, 12],
        [7, 15, 5, 6842, 82, 0, 70, 0, 0, 0, 31, 10, 23, 6, 9],
        [8, 5, 4, 3120, 82, 0, 72, 0, 0, 0, 31, 10, 23, 6, -3],
        [23, 11, 0, 6842, 82, 0, 72, 1, 0, 1, 31, 10, 23, 6, 9],
        // event days, in calendar order (2026 unless a year is given)
        [10, 30, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 1, 1, 5, -2],          // 正月
        [11, 20, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 2, 3, 3, 3],           // 节分
        [18, 30, 1, 6842, 82, 0, 72, 0, 0, 0, 31, 2, 14, 7, 6],          // 情人节
        [21, 30, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 2, 16, 2, 2],          // 除夕
        [13, 30, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 3, 3, 4, 12, 2027],    // 女儿节
        [14, 30, 1, 6842, 82, 0, 72, 0, 0, 0, 31, 3, 29, 1, 17],         // 赏樱
        [11, 0, 2, 6842, 82, 0, 72, 0, 0, 0, 31, 4, 5, 1, 14],           // 清明
        [10, 30, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 3, 28, 1, 15, 2027],   // 复活节
        [12, 30, 1, 6842, 82, 0, 72, 0, 0, 0, 31, 5, 5, 3, 22],          // 男孩节
        [15, 30, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 6, 1, 2, 27],          // 儿童节
        [9, 30, 1, 6842, 82, 0, 72, 0, 0, 0, 31, 6, 19, 6, 28],          // 端午
        [21, 30, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 7, 7, 3, 26],          // 七夕 (公历)
        [20, 30, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 8, 14, 6, 26],         // 盂兰盆
        [21, 30, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 8, 19, 4, 27],         // 七夕 (农历)
        [13, 30, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 10, 18, 1, 19],        // 重阳
        [14, 30, 1, 6842, 82, 0, 72, 0, 0, 0, 31, 11, 15, 1, 12],        // 红叶
        [22, 30, 0, 6842, 82, 0, 72, 0, 0, 0, 31, 12, 31, 5, -3],        // 跨年
        // overlaps: fireworks and the 中秋 moon stepping round the volcano and the low-battery bolt
        [22, 30, 0, 11204, 12, 0, 72, 0, 0, 0, 86, 1, 1, 5, -2],
        [21, 30, 0, 6842, 12, 0, 72, 0, 0, 0, 86, 9, 25, 6, 18]
    ];
    var i = (System.getTimer() / 5000) % presets.size();
    var p = presets[i] as Array<Number>;
    m.hour = p[0]; m.min = p[1]; m.weatherClass = p[2]; m.steps = p[3]; m.stepGoal = 10000;
    m.battery = p[4]; m.charging = p[5] == 1; m.bodyBattery = p[6]; m.notifications = p[7]; m.moveBar = p[8];
    m.demoAod = p[9] == 1;
    m.hr = 64; m.temp = p[14]; m.phone = true;
    m.stress = p[10]; m.calories = 1840; m.altitude = 128; m.is24 = true;
    m.sunrise = 6 * 3600 + 3 * 60; m.sunset = 17 * 3600 + 12 * 60;
    m.year = p.size() > 15 ? p[15] : 2026; m.month = p[11]; m.day = p[12]; m.weekday = p[13];
    m.termText = Cal.term(m.year, m.month, m.day); m.lunarText = Cal.lunarText(m.year, m.month, m.day);
    if (i != m.demoIndex) { m.demoIndex = i; m.revision += 1; System.println("preset " + i); }
}

(:nodemo)
function demoApply(m as Model) as Void { }

// demo and diagnostic builds: how long the frames of one wake took to paint, summed up and written once
// when the watch sleeps so the logging doesn't slow the frames it measures (simulator console, or
// GARMIN/Apps/LOGS/MOUNTAIN.TXT on a watch when that file exists)
(:prof)
var demoStats as Array<Number> = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; // intro, then ambient: frames, ms, max, gaps, gap ms
(:prof)
var demoPrev as Number = 0;
(:prof)
var demoProf as Dictionary = {};  // per-section ms over the same frames, from prof()
(:prof)
var demoLast as Number = 0;

(:prof)
function demoFrame(ms as Number, t as Float, rebuilt as Boolean) as Void {
    var now = System.getTimer();
    var k = t < Lay.INTRO ? 0 : 5;
    demoStats[k] += 1;
    demoStats[k + 1] += ms;
    if (ms > demoStats[k + 2]) { demoStats[k + 2] = ms; }
    if (demoPrev > 0 && now - demoPrev < 1000) { demoStats[k + 3] += 1; demoStats[k + 4] += now - demoPrev; }
    demoPrev = now;
    if (rebuilt) { System.println("rebuilt a still layer in " + ms + " ms at t " + t.format("%.2f")); }
}

(:prof)
function demoDump(why as String) as Void {
    if (demoStats[0] + demoStats[5] == 0) { return; }
    var st = System.getSystemStats();
    var line = why;
    for (var k = 0; k < 10; k += 5) {
        var n = demoStats[k];
        if (n == 0) { continue; }
        line += (k == 0 ? " | intro " : " | ambient ") + n + " frames, avg " + demoStats[k + 1] / n + " ms, max " + demoStats[k + 2]
              + " ms, every " + (demoStats[k + 3] > 0 ? demoStats[k + 4] / demoStats[k + 3] : 0) + " ms";
    }
    System.println(line + " | memory " + st.usedMemory + "/" + st.totalMemory);
    System.println("  sections (ms total) " + demoProf.toString());
    demoStats = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    demoProf = {};
    demoPrev = 0;
}

(:noprof)
function demoFrame(ms as Number, t as Float, rebuilt as Boolean) as Void { }

(:noprof)
function demoDump(why as String) as Void { }

(:prof)
function trace(msg as String) as Void { System.println(System.getTimer() + " " + msg); }

(:noprof)
function trace(msg as String) as Void { }

// per-section paint time: prof(null) starts the clock, prof(name) adds the time since the last call to name
(:prof)
function prof(name as String or Null) as Void {
    var now = System.getTimer();
    if (name != null) {
        var v = demoProf.get(name);
        demoProf.put(name, (v == null ? 0 : v as Number) + now - demoLast);
    }
    demoLast = now;
}

(:noprof)
function prof(name as String or Null) as Void { }
