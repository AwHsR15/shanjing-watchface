using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.ActivityMonitor;
using Toybox.SensorHistory;
using Toybox.Weather;
using Toybox.Math;

class MountainApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function getInitialView() { return [new MountainView()]; }
    function getSettingsView() { return [new SkyMenu(),new SkyMenuDelegate()]; }
    function onSettingsChanged() { WatchUi.requestUpdate(); }
}

class SkyMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>"山境 · 天空"});
        addItem(new WatchUi.MenuItem("自动昼夜",null,0,{}));
        addItem(new WatchUi.MenuItem("晴日青山",null,1,{}));
        addItem(new WatchUi.MenuItem("月下雪峰",null,2,{}));
        addItem(new WatchUi.MenuItem("日照金山",null,3,{}));
    }
}
class SkyMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        Application.Properties.setValue("Theme",item.getId());
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
    }
}

class MountainView extends WatchUi.WatchFace {
    var asleep = false;
    var digits, small, medium;
    var hr = null, altitude = null, stress = null, weather = null;
    var lastRead = -1;
    function initialize() { WatchFace.initialize(); }
    function onLayout(dc) {
        digits = WatchUi.loadResource(Rez.Fonts.TimeFont);
        small = WatchUi.loadResource(Rez.Fonts.SmallFont);
        medium = WatchUi.loadResource(Rez.Fonts.MediumFont);
    }
    function onEnterSleep() { asleep = true; }
    function onExitSleep() { asleep = false; WatchUi.requestUpdate(); }
    function val(n) { return n == null ? "--" : n.toNumber().toString(); }
    function setting(key, fallback) {
        var v = Application.Properties.getValue(key);
        return v == null ? fallback : v;
    }
    function readSensors() {
        var now = Time.now().value();
        if (lastRead >= 0 && now - lastRead < 60) { return; }
        lastRead = now;
        hr = null; altitude = null; stress = null; weather = null;
        try {
            var h = SensorHistory.getHeartRateHistory({:period => 1}).next();
            if (h != null && h.data != null && h.data > 0 && now-h.when.value() < 300) { hr=h.data; }
            var e = SensorHistory.getElevationHistory({:period => 1}).next();
            if (e != null && e.data != null && now-e.when.value() < 900) { altitude=e.data; }
            if (SensorHistory has :getStressHistory) {
                var s = SensorHistory.getStressHistory({:period => 1}).next();
                if (s != null && s.data != null && s.data >= 0 && now-s.when.value() < 900) { stress=s.data; }
            }
        } catch (ex) { }
        try {
            weather = Weather.getCurrentConditions();
            if (weather != null && (weather.observationTime == null || now-weather.observationTime.value() > 7200)) { weather=null; }
        } catch (ex) { }
    }
    function text(dc,x,y,font,t,color) {
        dc.setColor(color,Graphics.COLOR_TRANSPARENT);
        dc.drawText(x,y,font,t,Graphics.TEXT_JUSTIFY_CENTER);
    }
    function poly(dc,points,color) { dc.setColor(color,Graphics.COLOR_TRANSPARENT); dc.fillPolygon(points); }
    function blend(a,b,t) {
        var r=(((a>>16)&255)*(1-t)+((b>>16)&255)*t).toNumber();
        var g=(((a>>8)&255)*(1-t)+((b>>8)&255)*t).toNumber();
        var bl=((a&255)*(1-t)+(b&255)*t).toNumber();
        return (r<<16)|(g<<8)|bl;
    }
    function onUpdate(dc) {
        var clock=System.getClockTime();
        var ds=System.getDeviceSettings();
        var hour=clock.hour;
        if (!ds.is24Hour) { hour=hour%12; if(hour==0){hour=12;} }
        var time=hour.format("%02d")+":"+clock.min.format("%02d");
        dc.setColor(0,0); dc.clear();
        if(asleep) {
            var shift=(clock.min%3-1)*12;
            text(dc,227+shift,205+shift,medium,time,0x777777);
            return;
        }
        readSensors();
        var stats=System.getSystemStats();
        var activity=ActivityMonitor.getInfo();
        var theme=setting("Theme",0);
        var night=theme==2 || (theme==0 && (clock.hour<6 || clock.hour>=19));
        var dusk=theme==3 || (theme==0 && (clock.hour==6 || clock.hour==17 || clock.hour==18));
        var wet=weather!=null && weather.precipitationChance!=null && weather.precipitationChance>=60;
        var volcano=stress!=null && stress>=setting("StressThreshold",70);
        var low=stats.battery<=setting("LowBattery",20);
        var goal=activity.calories!=null && activity.calories>=setting("CalorieGoal",2500);
        var phase=clock.sec;
        // Smooth sky kept inside the progress ring; native geometry is shared with the preview.
        for(var y=20;y<263;y+=1) {
            var dy=y-227;
            var half=Math.sqrt(207*207-dy*dy).toNumber();
            var top=night ? 0x0B142B : (dusk ? 0x302C44 : 0x163A4C);
            var bottom=night ? 0x32636B : (dusk ? 0xC08A70 : 0x77AAA8);
            if(wet){top=0x222E40;bottom=0x69828A;}
            var color=blend(top,bottom,(y-20)/243.0);
            dc.setColor(color,0); dc.fillRectangle(227-half,y,half*2,1);
        }
        if(night) {
            dc.setColor(0xD7E6E5,0); dc.fillCircle(325,115,14);
            dc.setColor(0x172E42,0); dc.fillCircle(331,110,13);
            for(var i=0;i<18;i++) {
                var sx=95+(i*47)%260; var sy=83+(i*31)%100;
                if((sx-227)*(sx-227)+(sy-227)*(sy-227)<180*180){
                    dc.setColor((i+phase)%5==0 ? 0xFFFFFF : 0x6B9CA9,0); dc.fillCircle(sx,sy,1);
                }
            }
        } else {
            dc.setColor(dusk ? 0xE6AD78 : 0xE7D9AB,0); dc.fillCircle(143,122,16);
        }
        if(wet) {
            dc.setColor(0xA2BEC9,0); dc.setPenWidth(2);
            for(var j=0;j<18;j++) {
                var rx=90+(j*37)%280; var ry=80+(j*23+phase*9)%125;
                if((rx-227)*(rx-227)+(ry-227)*(ry-227)<180*180){ dc.drawLine(rx,ry,rx-4,ry+10); }
            }
            dc.setPenWidth(1);
        }
        drawMountain(dc,volcano,dusk);
        if(volcano) {
            dc.setColor(0xFF9B45,0);
            for(var k=0;k<7;k++){ dc.fillCircle(244+(k*13)%32-16,108-(k*11+phase*3)%32,2); }
        }
        if(low || stats.charging) {
            poly(dc,[[349,102],[339,121],[347,121],[341,137],[359,116],[350,116]],0xF8CC68);
        }
        if(goal) {
            var colors=[0xDA766B,0xE9B85E,0x86B88D,0x72B4CC];
            dc.setPenWidth(3);
            for(var r=0;r<4;r++){dc.setColor(colors[r],0);dc.drawArc(227,227,137-r*4,Graphics.ARC_CLOCKWISE,150,30);}
            dc.setPenWidth(1);
        }
        // Edge light tracks steps; it never encodes simulated values in the install build.
        dc.setPenWidth(3);dc.setColor(0x203033,0);
        dc.drawArc(227,227,218,Graphics.ARC_CLOCKWISE,225,-45);
        if(activity.steps!=null && activity.stepGoal!=null && activity.stepGoal>0 && activity.steps>0){
            var progress=Math.min(1.0,activity.steps.toFloat()/activity.stepGoal);
            dc.setColor(0xC6B38C,0);dc.drawArc(227,227,218,Graphics.ARC_CLOCKWISE,225,225-progress*270);
        }
        dc.setPenWidth(1);
        text(dc,227,261,digits,time,0xF3F2E7);
        text(dc,381,310,small,clock.sec.format("%02d"),0xB8C9C6);
        text(dc,73,274,small,ds.is24Hour ? "24H" : (clock.hour<12 ? "AM" : "PM"),0x869A9D);
        text(dc,87,178,small,"ALT",0xC3D4CD);
        text(dc,87,201,small,val(altitude)+"M",0xE7ECE3);
        text(dc,367,178,small,"TEMP",0xC3D4CD);
        text(dc,367,201,small,weather==null ? "--" : val(weather.temperature)+"C",0xE7ECE3);
        var d=Gregorian.info(Time.now(),Time.FORMAT_SHORT);
        var days=["SUN","MON","TUE","WED","THU","FRI","SAT"];
        var months=["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"];
        text(dc,227,40,small,days[d.day_of_week-1]+"  "+d.day.format("%02d")+"  "+months[d.month-1],0xE0E6DC);
        text(dc,227,66,small,"B "+val(stats.battery)+"%",0xA9BAB4);
        dc.setColor(0x30413F,0);dc.drawLine(104,351,350,351);
        dc.setColor(0xC6B38C,0);dc.fillCircle(227,351,2);
        text(dc,124,366,medium,val(activity.steps),0xE0E7DD);
        text(dc,227,366,medium,val(hr),0xE0E7DD);
        text(dc,330,366,medium,val(activity.calories),0xE0E7DD);
        text(dc,124,401,small,"STEPS",0x829790);text(dc,227,401,small,"HEART",0x829790);text(dc,330,401,small,"KCAL",0x829790);
        var status="M O U N T A I N";
        if(activity.moveBarLevel!=null && activity.moveBarLevel>=1){status="TIME TO MOVE";}
        if(ds.notificationCount>0){status="MSG "+ds.notificationCount;}
        if(low){status="LOW BATTERY";}
        if(stats.charging){status="CHARGING";}
        text(dc,227,428,small,status,0xC6B38C);
    }
}
