import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Event days: which one today is, how it tints the sky, and what it adds to the scene.
// Twin of the "event days" section in preview-render.js.
//  1 春节  2 元宵  3 中秋/月见  4 圣诞  5 万圣  6 除夕  7 正月/元旦  8 情人节  9 儿童节  10 端午  11 七夕(农历)
// 12 重阳  13 跨年  14 清明  15 节分  16 女儿节  17 赏樱  18 男孩节  19 七夕(公历)  20 盂兰盆  21 红叶  22 复活节
// Every piece has a fixed place, chosen so it stays clear of the volcano (summit), the bolt (349, 83),
// the chimney smoke and the sun ring.
module Ev {
    const NAMES = ["", "春节", "元宵", "中秋", "圣诞", "万圣", "除夕", "正月", "情人节", "儿童节", "端午", "七夕",
                   "重阳", "跨年", "清明", "节分", "女儿节", "赏樱", "男孩节", "七夕", "盂兰盆", "红叶", "复活节"];
    // each event leans the sky towards its own hue: zenith, mid, horizon, amount in percent
    const SKY = [0, 0, 0, 0,
        0x4A0F14, 0x8C2A22, 0xF0A050, 55,  0x2A0F2A, 0x6A2A3A, 0xF09A50, 45,  0x0C1430, 0x23305E, 0xD8A85A, 45,
        0x07241C, 0x14523C, 0x9FD0A8, 50,  0x1C0C2A, 0x5A2A4A, 0xF08A3A, 55,  0x4A0F14, 0x8C2A22, 0xF0A050, 55,
        0x0C1838, 0x2A3A78, 0xE8C070, 40,  0x3A1430, 0x8A3A6A, 0xF4A0B8, 50,  0x1A3A6A, 0x4A8AD0, 0xF8D080, 35,
        0x0C2A2A, 0x2A6A5A, 0xC8E0A0, 40,  0x140C30, 0x3A2A6A, 0xD890C0, 50,  0x2A1A0C, 0x7A5A2A, 0xF0C060, 40,
        0x0C1030, 0x2A2A68, 0xE8B860, 40,  0x1A2A2A, 0x5A7A72, 0xC0D8C8, 35,  0x2A1A10, 0x6A4A3A, 0xE8C090, 30,
        0x3A1A30, 0x9A5A7A, 0xF8C0D0, 45,  0x2A2A4A, 0x8A7AA8, 0xF8D0E0, 35,  0x1A4A7A, 0x5A9AD0, 0xD8F0F8, 30,
        0x140C30, 0x3A2A6A, 0xD890C0, 45,  0x1A0C20, 0x4A2A4A, 0xE89A60, 35,  0x2A140C, 0x7A3A24, 0xF0905A, 30,
        0x2A3A5A, 0x7AA0D0, 0xF0E0A0, 30];
    // firework centres in order of preference; slots near the bolt, the erupting summit or an earlier burst are skipped
    const SLOTS = [120, 66, 330, 58, 205, 38, 296, 50, 168, 52];
    const NEW_YEAR_SLOTS = [100, 80, 354, 74, 227, 40];

    // One event per day. Priority: lunar festivals > 除夕 > term days (清明, 节分) > fixed dates > Easter > seasons.
    function of(y as Number, m as Number, d as Number) as Number {
        var l = Cal.lunar(y, m, d);
        if (l != null && !(l[2] as Boolean)) {
            var lm = l[0] as Number;
            var ld = l[1] as Number;
            if (lm == 1 && ld <= 7) { return 1; }
            if (lm == 1 && ld == 15) { return 2; }
            if (lm == 5 && ld == 5) { return 10; }
            if (lm == 7 && ld == 7) { return 11; }
            if (lm == 8 && ld == 15) { return 3; }
            if (lm == 9 && ld == 9) { return 12; }
        }
        var nx = nextDay(y, m, d);
        var n = Cal.lunar(nx[0], nx[1], nx[2]);
        if (n != null && (n[0] as Number) == 1 && (n[1] as Number) == 1 && !(n[2] as Boolean)) { return 6; }
        var term = Cal.term(y, m, d);
        if (term != null && term.equals("清明")) { return 14; }
        term = Cal.term(nx[0], nx[1], nx[2]);
        if (term != null && term.equals("立春")) { return 15; }
        var md = m * 100 + d;
        if (md >= 101 && md <= 103) { return 7; }
        if (md == 214) { return 8; }
        if (md == 303) { return 16; }
        if (md == 505) { return 18; }
        if (md == 601) { return 9; }
        if (md == 707) { return 19; }
        if (md >= 813 && md <= 816) { return 20; }
        if (md == 1031) { return 5; }
        if (md == 1224 || md == 1225) { return 4; }
        if (md == 1231) { return 13; }
        var e = easter(y);
        if (m == e[0] && d == e[1]) { return 22; }
        if (md >= 325 && md <= 410) { return 17; }
        if (md >= 1110 && md <= 1125) { return 21; }
        return 0;
    }

    function nextDay(y as Number, m as Number, d as Number) as Array<Number> {
        var len = [31, Cal.isLeapYear(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1] as Number;
        if (d < len) { return [y, m, d + 1] as Array<Number>; }
        return (m < 12 ? [y, m + 1, 1] : [y + 1, 1, 1]) as Array<Number>;
    }

    // anonymous Gregorian computus -> [month, day]
    function easter(y as Number) as Array<Number> {
        var a = y % 19;
        var b = y / 100;
        var c = y % 100;
        var h = (19 * a + b - b / 4 - (b - (b + 8) / 25 + 1) / 3 + 15) % 30;
        var l = (32 + 2 * (b % 4) + 2 * (c / 4) - h - c % 4) % 7;
        var k = (a + 11 * h + 22 * l) / 451;
        return [(h + l - 7 * k + 114) / 31, (h + l - 7 * k + 114) % 31 + 1] as Array<Number>;
    }

    function wantsFireworks(s as Scene) as Boolean {
        var fest = s.fest;
        if (s.day) { return false; }
        if (fest == 1 || fest == 6 || fest == 7 || fest == 13) { return true; }
        // events whose sky already has a centrepiece get no extra goal fireworks
        return s.goal && fest != 3 && fest != 5 && fest != 11 && fest != 14;
    }

    // up to three burst centres, flat [x0, y0, x1, y1, ...]
    function fireworkSlots(s as Scene) as Array<Number> {
        var src = s.fest == 1 || s.fest == 6 ? NEW_YEAR_SLOTS : SLOTS;
        var keep = [] as Array<Number>;
        for (var i = 0; i < src.size() && keep.size() < 6; i += 2) {
            var x = src[i];
            var y = src[i + 1];
            var ok = !(s.lowBattery && near(x, y, 349, 83, 46)) && !(s.stress && near(x, y, 244, 58, 46));
            for (var j = 0; ok && j < keep.size(); j += 2) { ok = !near(x, y, keep[j], keep[j + 1], 56); }
            if (ok) { keep.add(x); keep.add(y); }
        }
        return keep;
    }

    function near(x as Number, y as Number, a as Number, b as Number, r as Number) as Boolean {
        return (x - a) * (x - a) + (y - b) * (y - b) < r * r;
    }

    function wrap(v as Numeric, n as Numeric) as Float {
        return (v - (v / n).toNumber() * n).toFloat();
    }

    function star(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric, c as Number) as Void {
        var st = new [10] as Array;
        for (var i = 0; i < 10; i++) {
            var a = -Math.PI / 2 + i * Math.PI / 5;
            var rr = i % 2 == 1 ? r * 0.44 : r;
            st[i] = [x + rr * Math.cos(a), y + rr * Math.sin(a)];
        }
        dc.setFill(U.argb(255, c));
        dc.fillPolygon(st);
    }

    function summitFlag(dc as Graphics.Dc, c as Number) as Void {
        var x = Geo.APEX[0];
        var y = Geo.APEX[1];
        dc.setStroke(U.argb(255, 0x3A3440));
        dc.setPenWidth(1.5);
        dc.drawLine(x, y, x, y - 15);
        dc.setFill(U.argb(255, c));
        dc.fillPolygon([[x + 0.5, y - 15], [x + 12, y - 11], [x + 0.5, y - 7]]);
    }

    // ------------------------------------------------------------ static layer
    // sky centrepieces
    function sky(dc as Graphics.Dc, s as Scene) as Void {
        var fest = s.fest;
        if (fest == 1 || fest == 6) { // 春节 / 除夕: two red lanterns, leaving the middle and both sides free for fireworks
            for (var i = 0; i < 2; i++) {
                var x = i == 0 ? 170 : 284;
                var len = i == 0 ? 30 : 24;
                dc.setStroke(U.argb(200, 0x3A1010));
                dc.setPenWidth(1);
                dc.drawLine(x, 16, x, 16 + len);
                s.drawGlow(dc, x, 28 + len, 9, 0xFF5A3A, 0.7);
                dc.setFill(U.argb(255, 0xD8282A));
                dc.fillEllipse(x, 28 + len, 11, 9);
                dc.setFill(U.argb(255, 0xF2C255));
                dc.fillRectangle(x - 5, 18 + len, 10, 3);
                dc.fillRectangle(x - 5, 36 + len, 10, 3);
                dc.setStroke(U.argb(255, 0xF2C255));
                dc.drawLine(x, 39 + len, x, 46 + len);
            }
        } else if (fest == 3) { // 中秋 / 月见: a large golden moon right of the peak, or left of it when the volcano is out
            var mx = s.stress ? 156 : 290;
            var my = s.stress ? 96 : 100;
            s.drawGlow(dc, mx, my, 20, 0xFFD890, 0.9);
            dc.setFill(U.argb(255, 0xFBE6B0));
            dc.fillCircle(mx, my, 20);
            dc.setFill(U.argb(40, 0xC89A50));
            dc.fillCircle(mx - 7, my - 6, 5);
            dc.fillCircle(mx + 6, my + 7, 4);
            dc.fillCircle(mx + 4, my - 8, 3);
        } else if (fest == 4) { // 圣诞: a star on the summit, unless the volcano has it
            if (!s.stress) {
                s.drawGlow(dc, Geo.APEX[0], Geo.APEX[1] - 12, 6, 0xFFE08A, 0.9);
                star(dc, Geo.APEX[0], Geo.APEX[1] - 12, 8, 0xFFD75A);
            }
        } else if (fest == 5) { // 万圣: an orange harvest moon
            s.drawGlow(dc, 128, 92, 18, 0xFF9A40, 0.9);
            dc.setFill(U.argb(255, 0xF6A24A));
            dc.fillCircle(128, 92, 18);
        } else if (fest == 11) { // 七夕: 牛郎 and 织女 either side of the Milky Way, magpies bridging it
            for (var i = 0; i < 2; i++) {
                var x = i == 0 ? 150 : 304;
                var y = i == 0 ? 78 : 46;
                var c = i == 0 ? 0xFFF0D0 : 0xD8E8FF;
                s.drawGlow(dc, x, y, 3, c, s.day ? 0.5 : 1);
                dc.setFill(U.argb(255, c));
                dc.fillCircle(x, y, 2.2);
            }
            dc.setStroke(U.argb(s.day ? 150 : 200, s.day ? 0x2A2440 : 0xC8D0E8));
            dc.setPenWidth(1.3);
            for (var i = 0; i < 9; i++) {
                var k = (i + 1) / 10.0;
                var x = 150 + 154 * k;
                var y = 78 - 32 * k - Math.sin(Math.PI * k) * 26;
                dc.drawLine(x - 4, y - 2, x, y);
                dc.drawLine(x, y, x + 4, y - 2);
            }
        } else if (fest == 12) { // 重阳: a flag on the summit (climbing day)
            if (!s.stress) { summitFlag(dc, 0xF0B030); }
        } else if (fest == 14) { // 清明: willow strands hanging from a branch that follows the inside of the sun ring
            var tops = [96, 76, 110, 65, 124, 56, 138, 48, 152, 42, 166, 37] as Array<Number>;
            dc.setStroke(U.argb(190, 0x4A5A2A));
            dc.setPenWidth(1.6);
            for (var i = 0; i < 10; i += 2) { dc.drawLine(tops[i], tops[i + 1], tops[i + 2], tops[i + 3]); }
            dc.setPenWidth(1.2);
            for (var i = 0; i < 6; i++) {
                var x0 = tops[2 * i];
                var y0 = tops[2 * i + 1];
                var len = 36 + (i % 3) * 14;
                dc.setStroke(U.argb(170, 0x6A8A3A));
                dc.drawLine(x0, y0, x0 + 5, y0 + len);
                dc.setFill(U.argb(200, 0x9AC060));
                for (var j = 1; j < 5; j++) { dc.fillEllipse(x0 + j, y0 + len * j / 5.0, 1.6, 3); }
            }
        }
    }

    // scattered dots on the hills: blossom, chrysanthemums, autumn colour
    function speckles(dc as Graphics.Dc, n as Number, salt as Number, cols as Array<Number>, alpha as Number, r as Numeric) as Void {
        for (var i = 0; i < n; i++) {
            var x = 20 + U.rnd(i, salt) * 414;
            var y = 176 + U.rnd(i, salt + 1) * 30;
            var top = Scene.skylineAt(x) + 4;
            if (y < top) { y = top; }
            if (y > Geo.HORIZON - 2) { continue; }
            dc.setFill(U.argb(alpha, cols[i % cols.size()]));
            dc.fillCircle(x, y, r + U.rnd(i, salt + 2));
        }
    }

    // land decorations that belong to the day
    function land(dc as Graphics.Dc, s as Scene) as Void {
        var fest = s.fest;
        if (fest == 12) { speckles(dc, 26, 101, [0xF6C43A, 0xF6C43A, 0xFFE07A] as Array<Number>, 220, 1.6); }
        else if (fest == 17) { speckles(dc, 40, 141, [0xF8C0D0, 0xFFE0EA, 0xF0A0B8] as Array<Number>, 220, 1.4); }
        else if (fest == 21) { speckles(dc, 40, 151, [0xD8402A, 0xE86A2A, 0xB02A1A] as Array<Number>, 200, 1.5); }
        else if (fest == 16) { // 女儿节: peach blossom on the near pines
            for (var i = 0; i < Geo.SHAPES.size(); i++) {
                if (Geo.ROLES[i] != 9) { continue; }
                var p = Geo.SHAPES[i] as Array<Number>;
                for (var k = 0; k < 3; k++) {
                    dc.setFill(U.argb(230, k % 2 == 1 ? 0xF8A0B8 : 0xFFD0DC));
                    dc.fillCircle(p[0] + (k - 1) * 3, p[1] + 5 + k * 4, 1.6);
                }
            }
        } else if (fest == 22) { // 复活节: painted eggs hidden on the hills
            var cols = [0xF8A0B8, 0x8AD0F0, 0xF8D870, 0xA8E090, 0xC8A0F0] as Array<Number>;
            for (var i = 0; i < 7; i++) {
                var x = 40 + U.rnd(i, 161) * 370;
                var y = 190 + U.rnd(i, 162) * 14;
                var top = Scene.skylineAt(x) + 6;
                if (y < top) { y = top; }
                if (y > Geo.HORIZON - 3) { continue; }
                dc.setFill(U.argb(255, cols[i % 5]));
                dc.fillEllipse(x, y, 2.6, 3.4);
                dc.setFill(U.argb(200, 0xFFFFFF));
                dc.fillRectangle(x - 2.6, y - 0.5, 5.2, 1);
            }
        } else if (fest == 20) { // 盂兰盆: a string of paper lanterns between the right-hand pines
            dc.setStroke(U.argb(160, 0x2A2018));
            dc.setPenWidth(1);
            dc.drawLine(356, 162, 420, 166);
            for (var i = 0; i < 5; i++) {
                var x = 362 + i * 13;
                var y = 168 + Math.sin(i * 1.3) * 1.5;
                if (!s.day) { s.drawGlow(dc, x, y, 3, 0xFFA050, 0.6); }
                dc.setFill(U.argb(255, i % 2 == 1 ? 0xF4EAD8 : 0xE8503A));
                dc.fillEllipse(x, y, 3.2, 4.2);
            }
        }
    }

    // decorations at the cabin
    function cabin(dc as Graphics.Dc, s as Scene) as Void {
        var fest = s.fest;
        if (fest == 4) { // string lights along the roof
            var cols = [0xFF5A5A, 0x7AE08A, 0xFFD36A, 0x6AB8FF] as Array<Number>;
            for (var i = 0; i < 7; i++) {
                dc.setFill(U.argb(255, cols[i % 4]));
                dc.fillCircle(314 + i * 4, 190 + (i - 3).abs() * 2.6, 1.3);
            }
        } else if (fest == 5) { // a pumpkin by the door
            s.drawGlow(dc, 312, 200, 4, 0xFF8A2A, 0.8);
            dc.setFill(U.argb(255, 0xF08A2A));
            dc.fillEllipse(312, 200, 4, 3);
        } else if (fest == 1 || fest == 6) { // red couplets round the door
            dc.setFill(U.argb(255, 0xD8282A));
            dc.fillRectangle(318.5, 193, 1.8, 7);
            dc.fillRectangle(326, 193, 1.8, 7);
            dc.fillRectangle(320, 190.5, 6, 1.8);
        } else if (fest == 10) { // 端午: calamus by the door
            dc.setStroke(U.argb(255, 0x5A9A3A));
            dc.setPenWidth(1.4);
            dc.drawLine(321, 192, 317, 202);
            dc.drawLine(325, 192, 329, 202);
            dc.setFill(U.argb(255, 0xE04A4A));
            dc.fillPolygon([[332, 196], [334, 198.5], [332, 201], [330, 198.5]]);
        } else if (fest == 7) { // 正月: kadomatsu beside the door
            dc.setFill(U.argb(255, 0x6A4A2A));
            dc.fillRectangle(305, 196, 10, 5);
            dc.setFill(U.argb(255, 0x4AA058));
            for (var i = 0; i < 3; i++) {
                var x = 307 + i * 3;
                var h = [11, 14, 10][i] as Number;
                dc.fillPolygon([[x - 1.2, 196], [x - 1.2, 196 - h + 2], [x + 1.2, 196 - h], [x + 1.2, 196]]);
            }
            dc.setFill(U.argb(255, 0x2A6A3A));
            dc.fillEllipse(310, 195, 6, 2.5);
        } else if (fest == 15) { // 节分: holly and a sardine head over the door
            dc.setStroke(U.argb(255, 0x3A7A3A));
            dc.setPenWidth(1.4);
            dc.drawLine(323, 190, 323, 184);
            dc.setFill(U.argb(255, 0x3A7A3A));
            dc.fillEllipse(321, 184, 2, 1.4);
            dc.fillEllipse(325, 185, 2, 1.4);
            dc.setFill(U.argb(255, 0xA8B0B8));
            dc.fillEllipse(323, 187, 1.2, 2.5);
        } else if (fest == 19) { // 七夕 (公历): a bamboo branch with paper wishes, leaning left, away from the chimney smoke
            dc.setStroke(U.argb(255, 0x4A8A3A));
            dc.setPenWidth(1.6);
            dc.drawLine(312, 202, 302, 166);
            var cols = [0xF05A5A, 0xF8D050, 0x5AB0F0, 0x8AD070, 0xD08AF0] as Array<Number>;
            dc.setPenWidth(1);
            for (var i = 0; i < 5; i++) {
                var x = 311 - i * 2.2;
                var y = 196 - i * 7;
                dc.setStroke(U.argb(255, 0x5AA04A));
                dc.drawLine(x, y, x - 6, y - 2);
                dc.setFill(U.argb(255, cols[i]));
                dc.fillRectangle(x - 6, y - 1, 2, 5);
            }
        }
    }

    // ------------------------------------------------------------ moving parts
    function motion(dc as Graphics.Dc, s as Scene, t as Float, rich as Boolean) as Void {
        var fest = s.fest;
        if (fest == 8) { hearts(dc, t, rich); }
        else if (fest == 9) { balloons(dc, t, rich); }
        else if ((fest == 7 || fest == 13) && s.day) { falling(dc, t, rich, 0); }
        else if (fest == 17 || fest == 16) { falling(dc, t, rich, 1); }
        else if (fest == 21) { falling(dc, t, rich, 2); }
        else if (fest == 14) { kite(dc, t, rich); }
        else if (fest == 15) { beans(dc, t, rich); }
        else if (fest == 18) { koinobori(dc, t, rich); }
    }

    // 情人节: hearts drifting up
    function hearts(dc as Graphics.Dc, t as Float, rich as Boolean) as Void {
        for (var i = 0; i < 7; i++) {
            var ph = wrap((rich ? t * 0.07 : 0.4) + U.rnd(i, 111), 1);
            var x = 70 + U.rnd(i, 112) * 314 + Math.sin(ph * 7 + i) * 8;
            var y = 205 - ph * 180;
            var r = 3 + U.rnd(i, 113) * 2.5;
            dc.setFill(U.argb(220 * U.clamp((1 - ph) * 3, 0, 1), i % 2 == 1 ? 0xFF7AA0 : 0xFFB0C8));
            dc.fillCircle(x - r * 0.5, y - r * 0.2, r * 0.62);
            dc.fillCircle(x + r * 0.5, y - r * 0.2, r * 0.62);
            dc.fillPolygon([[x - r * 1.1, y], [x + r * 1.1, y], [x, y + r * 1.2]]);
        }
    }

    // 儿童节: balloons rising from the meadow
    function balloons(dc as Graphics.Dc, t as Float, rich as Boolean) as Void {
        var cols = [0xFF6A6A, 0xFFCF4A, 0x6AC8FF, 0x8AE07A, 0xD08AFF] as Array<Number>;
        dc.setPenWidth(1);
        for (var i = 0; i < 6; i++) {
            var ph = wrap((rich ? t * 0.05 : 0.45) + U.rnd(i, 121), 1);
            var x = 70 + U.rnd(i, 122) * 314 + Math.sin(ph * 6 + i) * 6;
            var y = 210 - ph * 190;
            dc.setStroke(U.argb(160, 0xD8D8D8));
            dc.drawLine(x, y + 7, x + Math.sin(t * 2 + i) * 2, y + 20);
            dc.setFill(U.argb(240, cols[i % 5]));
            dc.fillEllipse(x, y, 5.5, 7);
            dc.setFill(U.argb(120, 0xFFFFFF));
            dc.fillEllipse(x - 2, y - 3, 1.5, 2.2);
        }
    }

    // falling things: 0 confetti, 1 sakura petals, 2 maple leaves
    function falling(dc as Graphics.Dc, t as Float, rich as Boolean, kind as Number) as Void {
        var cols = (kind == 0 ? [0xFFD36A, 0xFF6A6A, 0x6AD8C8, 0xFFFFFF] : kind == 1 ? [0xFFC8D8, 0xFFE4EC, 0xF8A8C0]
                                                                          : [0xD8402A, 0xE8702A, 0xC0301A, 0xF0A030]) as Array<Number>;
        var n = kind == 0 ? 30 : 22;
        var speed = kind == 0 ? 30 : (kind == 1 ? 16 : 22);
        for (var i = 0; i < n; i++) {
            var y = wrap(U.rnd(i, 131) * 190 + (rich ? t * (speed + U.rnd(i, 132) * speed) : 0), 190) + 24;
            var x = 50 + U.rnd(i, 133) * 354 + (rich ? Math.sin(t * 1.5 + i) * (kind == 0 ? 7 : 14) : 0);
            if ((x - 227) * (x - 227) + (y - 227) * (y - 227) > 190 * 190) { continue; }
            var spin = Math.sin((rich ? t * 4 : 0) + i).abs();
            var c = cols[i % cols.size()];
            dc.setFill(U.argb(230, c));
            if (kind == 0) { dc.fillRectangle(x - (1 + 2.5 * spin) / 2, y, 1 + 2.5 * spin, 3); }
            else if (kind == 1) { dc.fillEllipse(x, y, 1 + 2 * spin, 2.2); }
            else { star(dc, x, y, 2.5 + spin * 1.5, c); }
        }
    }

    // 清明: a kite on a long string, tied left of the cabin
    function kite(dc as Graphics.Dc, t as Float, rich as Boolean) as Void {
        var x = 284 + (rich ? Math.sin(t * 1.1) * 6 : 0);
        var y = 74 + (rich ? Math.cos(t * 0.9) * 3 : 0);
        dc.setStroke(U.argb(150, 0xE0E0E0));
        dc.setPenWidth(1);
        dc.drawLine(x, y + 9, 300, 198);
        dc.setFill(U.argb(255, 0xE85A4A));
        dc.fillPolygon([[x, y - 10], [x + 7, y], [x, y + 9], [x - 7, y]]);
        dc.setFill(U.argb(255, 0xFFD06A));
        dc.fillPolygon([[x, y - 10], [x + 7, y], [x, y]]);
        dc.setStroke(U.argb(200, 0xFFD06A));
        for (var i = 0; i < 4; i++) {
            var tx = x - 2 - i * 5;
            var ty = y + 12 + i * 6 + Math.sin(t * 3 + i) * 2;
            dc.drawLine(tx - 2, ty - 2, tx + 2, ty + 2);
        }
    }

    // 节分: roasted beans tossed out of the cabin door
    function beans(dc as Graphics.Dc, t as Float, rich as Boolean) as Void {
        dc.setFill(U.argb(240, 0xE0C080));
        for (var i = 0; i < 9; i++) {
            var ph = wrap((rich ? t * 0.8 : 0.5) + i / 9.0, 1);
            var x = 323 - (40 + U.rnd(i, 171) * 60) * ph;
            var y = 194 - (70 + U.rnd(i, 172) * 40) * ph + 120 * ph * ph;
            if (y <= 202) { dc.fillCircle(x, y, 1.6); }
        }
    }

    // 男孩节: carp streamers on a pole beside the cabin
    function koinobori(dc as Graphics.Dc, t as Float, rich as Boolean) as Void {
        dc.setStroke(U.argb(255, 0xD8D0C0));
        dc.setPenWidth(1.6);
        dc.drawLine(302, 202, 302, 128);
        var body = [0x2A2A38, 0xE0402A, 0x2A7AD8] as Array<Number>;
        var eye = [0xE8E8E8, 0xF8D0C0, 0xD0E8F8] as Array<Number>;
        for (var k = 0; k < 3; k++) {
            var y0 = 134 + k * 11;
            var len = 26 - k * 3;
            var pts = new [18] as Array;
            for (var i = 0; i <= 8; i++) {
                var u = i / 8.0;
                var x = 304 + u * len;
                var w = (rich ? Math.sin(t * 5 - u * 5 + k) : 0.3) * 2.5 * u;
                var h = 4.5 * (1 - u * 0.35);
                pts[i] = [x, y0 - h + w];
                pts[17 - i] = [x, y0 + h + w];
            }
            dc.setFill(U.argb(255, body[k]));
            dc.fillPolygon(pts);
            dc.setFill(U.argb(255, eye[k]));
            dc.fillCircle(308, y0 - 1, 1.6);
        }
    }
}
