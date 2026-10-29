using Toybox.Test;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.System;
using Toybox.Time;

(:test)
class TestWeather {
    var precipitationChance = 80;
    var temperature = 18;
}

(:test)
function renderThemesAndSleep(logger) {
    var bitmap=Graphics.createBufferedBitmap({:width=>454,:height=>454});
    var dc=bitmap.get().getDc();
    var view=new MountainView();
    view.onLayout(dc);
    for(var theme=0;theme<4;theme++) {
        Application.Properties.setValue("Theme",theme);
        view.onUpdate(dc);
        logger.debug("Rendered theme "+theme);
    }
    view.onEnterSleep(); view.onUpdate(dc);
    logger.debug("Rendered low-power clock");
    view.onExitSleep(); view.onUpdate(dc);
    view.lastRead=Time.now().value();
    view.stress=90;
    view.weather=new TestWeather();
    view.onUpdate(dc);
    logger.debug("Rendered rain and volcano together");
    Application.Properties.setValue("LowBattery",100);
    Application.Properties.setValue("CalorieGoal",0);
    view.onUpdate(dc);
    logger.debug("Rendered threshold-triggered reminders");
    view.hr=null;view.altitude=null;view.stress=null;view.weather=null;
    view.onUpdate(dc);
    logger.debug("Rendered missing sensor data");
    Application.Properties.setValue("Theme",0);
    Application.Properties.setValue("LowBattery",20);
    Application.Properties.setValue("CalorieGoal",2500);
    logger.debug("Resumed awake rendering");
    return true;
}
