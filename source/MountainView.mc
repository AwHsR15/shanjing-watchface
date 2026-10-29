import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Lifecycle and motion. On wrist raise: a 1.4 s intro at 20 fps (the scene fades in and rises, the
// readings count up, gauges sweep, the sun travels to its place on the ring), then ambient motion at
// 15 fps until the watch sleeps. Asleep, the always-on line drawing is painted once a minute.
class MountainView extends WatchUi.WatchFace {
    hidden var scene as Scene;
    hidden var model as Model;
    hidden var awake as Boolean = true;
    hidden var timer as Timer.Timer or Null = null;
    hidden var period as Number = 0;
    hidden var wakeAt as Number = 0;
    hidden var meteorAt as Float = -1.0;

    function initialize() {
        WatchFace.initialize();
        scene = new Scene();
        model = new Model();
    }

    function onLayout(dc as Graphics.Dc) as Void { scene.load(); }

    function onShow() as Void {
        trace("show");
        wake();
    }

    function onHide() as Void {
        trace("hide");
        stopTimer();
        demoDump("hide");
    }

    function onExitSleep() as Void {
        trace("exit sleep");
        awake = true;
        wake();
    }

    function onEnterSleep() as Void {
        trace("enter sleep");
        awake = false;
        stopTimer();
        demoDump("sleep");
        WatchUi.requestUpdate();
    }

    // called by the app when settings change on the phone or the watch
    function settingsChanged() as Void {
        model.refresh(true);
        WatchUi.requestUpdate();
    }

    hidden function wake() as Void {
        wakeAt = System.getTimer();
        model.refresh(true);
        meteorAt = (model.motion == 0 && Math.rand() % 3 != 0) ? 2.0 + (Math.rand() % 400) / 100.0 : -1.0;
        trace("wake, motion " + model.motion);
        // timers only run while the watch is awake (high-power); asleep, the always-on drawing needs none
        if (model.motion != 2 && awake) { startTimer(50); }
        WatchUi.requestUpdate();
    }

    hidden function startTimer(ms as Number) as Void {
        stopTimer();
        try {
            timer = new Timer.Timer();
            (timer as Timer.Timer).start(method(:tick), ms, true);
            period = ms;
        } catch (e) {
            // the watch refuses timers outside high-power mode (seen on EPIX Pro): fall back to the system's updates
            trace("timer refused: " + e.getErrorMessage());
            timer = null;
            period = 0;
        }
    }

    hidden function stopTimer() as Void {
        if (timer != null) {
            timer.stop();
            timer = null;
        }
        period = 0;
    }

    function tick() as Void {
        var t = (System.getTimer() - wakeAt) / 1000.0;
        if (!awake || t > 15) {
            trace("timer stop at " + t.format("%.1f"));
            stopTimer();
            demoDump("motion end");
            return;
        }
        if (period == 50 && t > Lay.INTRO) {
            // intro done: keep ambient motion at 15 fps, or fall back to the system's 1 Hz updates
            if (model.motion == 0) { startTimer(66); } else { stopTimer(); }
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        model.refresh(false);
        var shown = model.demoIndex;
        demoApply(model);
        if (shown != model.demoIndex) { // demo build: replay the wrist-raise intro for each scene
            wake();
            demoApply(model);
        }
        if (!awake || model.demoAod) {
            scene.drawAod(dc, model);
            return;
        }
        var t = (System.getTimer() - wakeAt) / 1000.0;
        var intro = model.motion == 2 ? 1.0 : U.clamp(t / Lay.INTRO, 0, 1).toFloat();
        var t0 = System.getTimer();
        scene.draw(dc, model, intro, t.toFloat(), meteorAt);
        demoFrame(System.getTimer() - t0, t.toFloat(), scene.rebuilt);
        // a repaint of the static layer can take a moment on wake: start the intro clock after it
        if (scene.rebuilt && intro < 0.3) { wakeAt = System.getTimer(); }
    }
}
