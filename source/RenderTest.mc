import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

// Renders every scene the face can show into an off-screen bitmap: each sky, each weather class,
// the intro frames, missing data, alerts and the always-on drawing. Only built with `-t`.
(:test)
function renderAllScenes(logger as Logger) as Boolean {
    var bitmap = Graphics.createBufferedBitmap({:width => 454, :height => 454});
    var dc = bitmap.get().getDc();
    var scene = new Scene();
    scene.load();
    var m = new Model();
    m.refresh(true);
    m.steps = 6842; m.stepGoal = 10000; m.hr = 64; m.bodyBattery = 72; m.temp = 16; m.calories = 1840; m.altitude = 128; m.stress = 85;
    m.month = 10; m.day = 23; m.weekday = 6; m.year = 2026;
    m.termText = Cal.term(2026, 10, 23);
    m.lunarText = Cal.lunarText(2026, 10, 23);
    Test.assertEqualMessage(m.termText, "霜降", "2026-10-23 is 霜降");
    Test.assertEqualMessage(m.lunarText, "九月十四", "2026-10-23 is 九月十四");
    Test.assertEqualMessage(Cal.lunarText(2025, 7, 25), "闰六月初一", "leap month 2025");
    Test.assertEqualMessage(Cal.lunarText(2026, 2, 17), "正月初一", "new year 2026");

    for (var sky = 0; sky < 5; sky++) {
        m.sky = sky; m.revision += 1;
        scene.draw(dc, m, 1.0, 3.0, -1.0);
        logger.debug("sky " + sky);
    }
    m.sky = 0;
    for (var hour = 0; hour < 24; hour += 3) {
        m.hour = hour; m.revision += 1;
        scene.draw(dc, m, 1.0, 3.0, 2.0);
    }
    logger.debug("hours 0-21");
    for (var w = 0; w < 7; w++) {
        m.weatherClass = w; m.revision += 1;
        scene.draw(dc, m, 1.0, 5.35, -1.0);
        logger.debug("weather " + w);
    }
    // every event day of 2026, overlaps settled by priority (元宵 over 女儿节, 清明 over Easter), then plain days
    var dates = [[1, 1], [2, 3], [2, 14], [2, 16], [2, 17], [3, 3], [3, 29], [4, 5], [5, 5], [6, 1], [6, 19], [7, 7],
                 [8, 14], [8, 19], [9, 25], [10, 18], [10, 31], [11, 15], [12, 24], [12, 31], [4, 12], [7, 18], [1, 8]] as Array<Array<Number> >;
    var expect = [7, 15, 8, 6, 1, 2, 17, 14, 18, 9, 10, 19, 20, 11, 3, 12, 5, 21, 4, 13, 0, 0, 0] as Array<Number>;
    m.weatherClass = 0;
    for (var i = 0; i < dates.size(); i++) {
        m.month = dates[i][0]; m.day = dates[i][1]; m.revision += 1;
        Test.assertEqualMessage(Ev.of(2026, m.month, m.day), expect[i], "event on 2026/" + m.month + "/" + m.day);
        m.hour = i % 2 == 0 ? 21 : 10;
        m.stress = i % 3 == 0 ? 85 : 31;
        m.battery = i % 4 == 0 ? 12 : 82;
        scene.draw(dc, m, 1.0, 2.0, -1.0);
    }
    Test.assertEqualMessage(Ev.of(2027, 3, 28), 22, "Easter 2027");
    Test.assertEqualMessage(Ev.of(2027, 3, 3), 16, "女儿节 2027");
    Test.assertEqualMessage(Ev.easter(2025)[1], 20, "Easter 2025 is 4/20");
    // fireworks keep clear of the bolt and the erupting summit
    scene.day = false; scene.goal = true; scene.fest = 0; scene.stress = true; scene.lowBattery = true;
    Test.assertEqualMessage(Ev.fireworkSlots(scene).toString(), "[120, 66, 296, 50]", "goal fireworks beside bolt and volcano");
    scene.fest = 1;
    Test.assertEqualMessage(Ev.fireworkSlots(scene).toString(), "[100, 80]", "new year fireworks beside bolt and volcano");
    scene.fest = 0; scene.stress = false; scene.lowBattery = false;
    Test.assertEqualMessage(Ev.fireworkSlots(scene).toString(), "[120, 66, 330, 58, 205, 38]", "fireworks on a clear sky");
    m.stress = 85; m.battery = 82;
    m.month = 10; m.day = 23;
    logger.debug("festivals and seasons");
    for (var i = 0; i <= 10; i++) { scene.draw(dc, m, i / 10.0, i * 0.11, -1.0); }
    logger.debug("intro frames");
    m.steps = 12000; m.battery = 12; m.charging = true; m.bodyBattery = 15; m.notifications = 4; m.moveBar = 3; m.phone = false;
    m.is24 = false;
    scene.draw(dc, m, 1.0, 3.0, -1.0);
    logger.debug("goal, low battery, alerts, 12h");
    m.steps = null; m.stepGoal = null; m.hr = null; m.bodyBattery = null; m.temp = null; m.lunarText = null; m.termText = null;
    m.revision += 1;
    scene.draw(dc, m, 1.0, 3.0, -1.0);
    logger.debug("missing data");
    for (var min = 0; min < 5; min++) { m.min = min; scene.drawAod(dc, m); }
    logger.debug("always-on");
    return true;
}
