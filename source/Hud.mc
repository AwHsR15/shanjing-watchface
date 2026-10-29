import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Text and icons. Twin of the "text (Hud.mc)" section in preview-render.js.
module Hud {
    const WEEK = ["日", "一", "二", "三", "四", "五", "六"];
    const ELEMENTS = ["日", "月", "火", "水", "木", "金", "土"];
    const WEEK_COLORS = [0xF2A65A, 0xC9D3E0, 0xF07A62, 0x6FB6E8, 0x7CC48A, 0xF0C75E, 0xC49A6C];

    function text(dc as Graphics.Dc, x as Numeric, y as Numeric, font as Graphics.FontType or Null, str as String,
                  color as Number, just as Number) as Void {
        if (font == null) { return; }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setFill(U.argb(255, color));
        dc.drawText(x, y, font, str, just);
    }

    function timeText(m as Model) as String {
        var h = m.is24 ? m.hour : (m.hour + 11) % 12 + 1;
        return U.pad2(h) + ":" + U.pad2(m.min);
    }

    function dateText(m as Model) as String {
        return "周" + WEEK[m.weekday - 1] + " " + U.pad2(m.month) + "/" + U.pad2(m.day);
    }

    // vertical position that centres SmallFont glyphs on y
    function smallTop(y as Numeric) as Numeric { return y - Fm.SMALLFONT_BASE + Fm.SMALLFONT_CAP / 2; }

    // e < 1 during the intro: the time slides up into place and the readings count up from zero
    function draw(dc as Graphics.Dc, s as Scene, m as Model, e as Float) as Void {
        text(dc, Lay.TIME_X, Lay.TIME_BASE - Fm.TIMEFONT_BASE + 16 * (1 - e), s.fTime, timeText(m), 0xF6F4EE, Graphics.TEXT_JUSTIFY_CENTER);
        prof("t_time");
        // left: weather over temperature; right: clock mode over seconds (seconds are drawn every frame)
        weather(dc, Lay.SIDE_X, 246, m.weatherClass, !s.day, 0xC9D6E6);
        text(dc, Lay.SIDE_X, 260, s.fValue, m.temp == null ? "--" : m.temp.toString() + "°", 0xF2EFE8, Graphics.TEXT_JUSTIFY_CENTER);
        text(dc, Lay.SIDE_RX, 236, s.fSmall, m.is24 ? "24H" : (m.hour < 12 ? "AM" : "PM"), 0x9AA6B2, Graphics.TEXT_JUSTIFY_CENTER);
        // the date: 七曜 seal, weekday and date, then the event day, the 节气 (on their day) or the 农历 date
        var term = s.fest > 0 ? Ev.NAMES[s.fest] : m.termText;
        var extra = term != null ? term : (m.lunarText != null ? m.lunarText : "");
        var date = dateText(m);
        var cy = Lay.DATE_Y + Fm.TEXTFONT_BASE - Fm.TEXTFONT_CAP / 2;
        var seal = 26;
        var w1 = dc.getTextWidthInPixels(date, s.fText);
        var w2 = extra.length() > 0 ? dc.getTextWidthInPixels(extra, s.fText) + 12 : 0;
        var left = 227 - (seal + 9 + w1 + w2) / 2;
        var wk = m.weekday - 1;
        dc.setFill(U.argb(255, WEEK_COLORS[wk]));
        dc.fillRoundedRectangle(left, cy - seal / 2, seal, seal, 6);
        text(dc, left + seal / 2, smallTop(cy), s.fSmall, ELEMENTS[wk], 0x16110A, Graphics.TEXT_JUSTIFY_CENTER);
        text(dc, left + seal + 9, Lay.DATE_Y, s.fText, date, 0xF2EFE8, Graphics.TEXT_JUSTIFY_LEFT);
        if (w2 > 0) { text(dc, left + seal + 9 + w1 + 12, Lay.DATE_Y, s.fText, extra, term != null ? s.accent : 0xC9B48E, Graphics.TEXT_JUSTIFY_LEFT); }
        // move alert: hatched bars either side of the date
        if (m.moveBar >= 1) {
            dc.setFill(U.argb(255, s.accent));
            var r = 227 + (227 - left) + 9;
            for (var i = 0; i < 4; i++) {
                var lx = left - 40 + i * 7;
                dc.fillPolygon([[lx, cy + 5], [lx + 4, cy - 5], [lx + 7, cy - 5], [lx + 3, cy + 5]]);
                var rx = r + i * 7;
                dc.fillPolygon([[rx, cy + 5], [rx + 4, cy - 5], [rx + 7, cy - 5], [rx + 3, cy + 5]]);
            }
        }
        prof("t_date");
        // one row of readings: heart rate and active calories (the sun ring already shows sunrise to sunset).
        // Laid out from the final values so nothing shifts while they count up; the heart beats in pulse().
        var hr = m.hr == null ? "--" : m.hr.toString();
        var kcal = m.calories == null ? "--" : m.calories.toString();
        var wh = dc.getTextWidthInPixels(hr, s.fValue);
        var wc = dc.getTextWidthInPixels(kcal, s.fValue);
        var x = 227 - (26 + wh + 28 + 26 + wc) / 2;
        var iy = Lay.INFO_Y + Fm.VALUEFONT_BASE - Fm.VALUEFONT_CAP / 2;
        s.heartX = x + 10;
        s.heartY = iy;
        text(dc, x + 26, Lay.INFO_Y, s.fValue, count(m.hr, e), 0xE8E6E0, Graphics.TEXT_JUSTIFY_LEFT);
        x += 26 + wh + 28;
        flame(dc, x + 10, iy, 0xFFA45A);
        text(dc, x + 26, Lay.INFO_Y, s.fValue, count(m.calories, e), 0xE8E6E0, Graphics.TEXT_JUSTIFY_LEFT);
        // watch battery between the two gauges
        var low = m.battery <= m.batteryLimit;
        var bc = low ? 0xFF6A55 : (m.charging ? 0x8FE39A : 0xA9B4C0);
        var bx = 227 - (22 + dc.getTextWidthInPixels(m.battery.toString() + "%", s.fSmall)) / 2;
        var level = (m.battery * e + 0.5).toNumber();
        battery(dc, bx + 10, Lay.BATTERY_Y + Fm.SMALLFONT_BASE - Fm.SMALLFONT_CAP / 2, level, bc);
        text(dc, bx + 24, Lay.BATTERY_Y, s.fSmall, level.toString() + "%", bc, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function count(v as Number or Null, e as Float) as String {
        return v == null ? "--" : (v * e + 0.5).toNumber().toString();
    }

    // the heart beside the heart rate, beating at the measured rate while the watch is awake (t < 0: still)
    function pulse(dc as Graphics.Dc, s as Scene, m as Model, t as Float) as Void {
        var k = 1.0;
        if (t >= 0 && m.hr != null && m.hr > 0) {
            var beat = t * m.hr / 60.0;
            var u = 1 - (beat - beat.toNumber());
            k = 1 + 0.24 * u * u * u * u;
        }
        heart(dc, s.heartX, s.heartY, 0xFF7A6E, k);
    }

    function seconds(dc as Graphics.Dc, s as Scene, m as Model) as Void {
        text(dc, Lay.SIDE_RX, 256, s.fValue, U.pad2(m.sec), 0xF2EFE8, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // always-on text: outline time, the seal as an outline, date and two readings, all dim
    function aod(dc as Graphics.Dc, s as Scene, m as Model, dx as Number, dy as Number) as Void {
        text(dc, Lay.TIME_X + dx, Lay.TIME_BASE - Fm.TIMELINE_BASE + dy, s.fLine, timeText(m), 0x8A929C, Graphics.TEXT_JUSTIFY_CENTER);
        var wk = m.weekday - 1;
        var date = dateText(m);
        var cy = Lay.DATE_Y + Fm.TEXTFONT_BASE - Fm.TEXTFONT_CAP / 2;
        var left = 227 - (26 + 9 + dc.getTextWidthInPixels(date, s.fText)) / 2;
        dc.setStroke(U.argb(255, U.mix(WEEK_COLORS[wk], 0, 0.5)));
        dc.setPenWidth(1.5);
        dc.drawRoundedRectangle(left + dx, cy - 13 + dy, 26, 26, 6);
        text(dc, left + 13 + dx, smallTop(cy) + dy, s.fSmall, ELEMENTS[wk], U.mix(WEEK_COLORS[wk], 0, 0.45), Graphics.TEXT_JUSTIFY_CENTER);
        text(dc, left + 35 + dx, Lay.DATE_Y + dy, s.fText, date, 0x6A727C, Graphics.TEXT_JUSTIFY_LEFT);
        var line = "HR " + (m.hr == null ? "--" : m.hr.toString()) + "  ·  " + m.battery + "%";
        text(dc, 227 + dx, Lay.INFO_Y + 4 + dy, s.fSmall, line, 0x4E5660, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // gauge label following the lower ring; straight text when the device has no vector font
    function radial(dc as Graphics.Dc, s as Scene, str as String, angle as Numeric, color as Number) as Void {
        if (s.vLabel != null && dc has :drawRadialText) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.setFill(U.argb(255, color));
            dc.drawRadialText(227, 227, s.vLabel, str, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER, angle, Lay.LABEL_R,
                              Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
            return;
        }
        var p = U.ringPoint(angle, Lay.LABEL_R);
        text(dc, p[0], smallTop(p[1]), s.fSmall, str, color, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function heart(dc as Graphics.Dc, x as Numeric, y as Numeric, c as Number, k as Numeric) as Void {
        dc.setFill(U.argb(255, c));
        dc.fillCircle(x - 3.6 * k, y - 2 * k, 4.2 * k);
        dc.fillCircle(x + 3.6 * k, y - 2 * k, 4.2 * k);
        dc.fillPolygon([[x - 7.6 * k, y - k], [x + 7.6 * k, y - k], [x, y + 7 * k]]);
    }

    function flame(dc as Graphics.Dc, x as Numeric, y as Numeric, c as Number) as Void {
        dc.setFill(U.argb(255, c));
        dc.fillPolygon([[x, y - 9], [x + 6, y - 1], [x + 5, y + 5], [x, y + 8], [x - 5, y + 5], [x - 6, y], [x - 3, y - 3], [x - 2, y + 1]]);
        dc.setFill(U.argb(255, U.mix(c, 0xFFFFFF, 0.55)));
        dc.fillEllipse(x, y + 4, 2.2, 3);
    }

    function battery(dc as Graphics.Dc, x as Numeric, y as Numeric, level as Number, c as Number) as Void {
        dc.setStroke(U.argb(255, c));
        dc.setPenWidth(1.5);
        dc.drawRoundedRectangle(x - 10, y - 5, 18, 10, 2.5);
        dc.setFill(U.argb(255, c));
        dc.fillRectangle(x + 8, y - 2, 2, 4);
        var w = 14 * level / 100.0;
        dc.fillRectangle(x - 8, y - 3, w < 1.5 ? 1.5 : w, 6);
    }

    function bolt(dc as Graphics.Dc, x as Numeric, y as Numeric, c as Number) as Void {
        dc.setFill(U.argb(255, c));
        dc.fillPolygon([[x + 2, y - 9], [x - 6, y + 1], [x - 1, y + 1], [x - 3, y + 9], [x + 6, y - 2], [x + 1, y - 2], [x + 3, y - 9]]);
    }

    function weather(dc as Graphics.Dc, x as Numeric, y as Numeric, cls as Number, night as Boolean, c as Number) as Void {
        if (cls == 0 || cls == 1) {
            if (night) {
                dc.setFill(U.argb(255, 0xE6ECF5));
                dc.fillCircle(x - 2, y - 3, 6);
                dc.setFill(U.argb(255, 0));
                dc.fillCircle(x + 1, y - 6, 5.5);
            } else {
                dc.setFill(U.argb(255, 0xFFCF7A));
                dc.fillCircle(x - 3, y - 3, 5);
                dc.setStroke(U.argb(255, 0xFFCF7A));
                dc.setPenWidth(1.6);
                for (var i = 0; i < 8; i++) {
                    var an = i * Math.PI / 4;
                    dc.drawLine(x - 3 + Math.cos(an) * 7.5, y - 3 + Math.sin(an) * 7.5, x - 3 + Math.cos(an) * 10, y - 3 + Math.sin(an) * 10);
                }
            }
            if (cls == 1) { cloud(dc, x, y + 3, c); }
            return;
        }
        if (cls == 5) {
            dc.setStroke(U.argb(255, c));
            dc.setPenWidth(2);
            for (var i = 0; i < 3; i++) { dc.drawLine(x - 9 + i * 2, y - 5 + i * 5, x + 9 - i * 2, y - 5 + i * 5); }
            return;
        }
        cloud(dc, x, y - 3, c);
        if (cls == 3 || cls == 6) {
            dc.setStroke(U.argb(255, 0x9CC8FF));
            dc.setPenWidth(1.6);
            for (var i = 0; i < 3; i++) { dc.drawLine(x - 5 + i * 5, y + 6, x - 7 + i * 5, y + 10); }
        }
        if (cls == 4) {
            dc.setFill(U.argb(255, 0xFFFFFF));
            for (var i = 0; i < 3; i++) { dc.fillCircle(x - 5 + i * 5, y + 8 + (i % 2) * 2, 1.4); }
        }
        if (cls == 6) { bolt(dc, x + 1, y + 6, 0xFFD36A); }
    }

    function cloud(dc as Graphics.Dc, x as Numeric, cy as Numeric, c as Number) as Void {
        dc.setFill(U.argb(255, c));
        dc.fillCircle(x - 4, cy + 1, 4.5);
        dc.fillCircle(x + 1.5, cy - 2, 6);
        dc.fillCircle(x + 6.5, cy + 1.5, 4);
        dc.fillRoundedRectangle(x - 8.5, cy + 1, 19, 5, 2.5);
    }
}
