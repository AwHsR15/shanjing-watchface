import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Layout shared with preview-render.js (const L there).
// Upper ~47%: the landscape, the sky filling the dial and darkening towards the rim; the sun path rides the top of the ring.
// Lower half (after 望山-X / v1): weather | big time | clock mode + seconds, the date with its 七曜 seal,
// one row of readings, and two gauges climbing the ring from the bottom with the watch battery between them.
module Lay {
    const RING_R = 218;
    const LABEL_R = 198;
    const TIME_X = 227;
    const TIME_BASE = 302;
    const SIDE_X = 72;
    const SIDE_RX = 384;
    const DATE_Y = 314;
    const INFO_Y = 354;
    const BATTERY_Y = 404;
    const STEPS = [264, 204];
    const BODY = [276, 336];
    const SUN_SPAN = [177, 3];
    const INTRO = 1.4;      // seconds
    const TRACK = 0x232A33;
    const ACCENTS = [0xE5A54B, 0x5FC8D8, 0xF08AA0, 0xE8ECF2];  // 琥珀 青 樱 雪
}

// Paints one frame. Everything that holds still for a minute (landscape, text, the ring) is rendered
// once into an off-screen bitmap; animation frames only copy it and add the moving parts. Twin of
// preview-render.js.
class Scene {
    var fTime as WatchUi.FontResource or Null = null;
    var fLine as WatchUi.FontResource or Null = null;
    var fText as WatchUi.FontResource or Null = null;
    var fValue as WatchUi.FontResource or Null = null;
    var fSmall as WatchUi.FontResource or Null = null;
    var vLabel as Graphics.VectorFont or Null = null; // device font for the gauge labels along the ring

    hidden var shapes as Array = [];
    hidden var stars as Array<Numeric> = []; // per star: x, y, radius, colour, brightness, twinkle rate, phase

    // two off-screen layers: the landscape, repainted only when the light or the scene changes, and
    // the landscape plus text and ring, repainted every minute. Animation frames copy one and add the moving parts.
    hidden var land as Graphics.BufferedBitmapReference or Null = null;
    hidden var landKey as Number = -1;
    hidden var landSig as Number = 0;
    hidden var cache as Graphics.BufferedBitmapReference or Null = null;
    hidden var cacheFailed as Boolean = false;
    hidden var cacheKey as Number = -1;
    hidden var cacheSun as Boolean = false;  // the cached ring left out the sun, which breathes when motion is on
    hidden var ringBaked as Boolean = false; // this frame's copy already had the ring and gauges in it
    var heartX as Numeric = 0;   // where the text layer left room for the beating heart
    var heartY as Numeric = 0;

    // per-minute state, read by Hud too
    hidden var rev as Number = -1;
    var pal as Array<Number> = [];
    var day as Boolean = true;
    var accent as Number = 0xE5A54B;
    var fest as Number = 0;      // event day, see Events.mc
    var season as Number = 0;    // 0 spring 1 summer 2 autumn 3 winter
    hidden var alt as Float = 30.0;
    hidden var f as Float = 0.5; // sun / moon position on its arc, 0 rising .. 1 setting
    var fx as Number = 0;
    hidden var overcast as Float = 0.0;
    hidden var starA as Float = 0.0;
    hidden var phase as Float = 0.0;
    var goal as Boolean = false;
    var stress as Boolean = false;
    var lowBattery as Boolean = false;
    hidden var slots as Array<Number> = []; // firework centres for the day
    hidden var fullMoon as Boolean = false;
    hidden var aurora as Boolean = false;
    hidden var sunLeft as Boolean = true;
    hidden var lit as Boolean = false;    // a message waiting: the cabin window glows
    var rebuilt as Boolean = false;   // true for a frame that had to repaint a still layer

    // tables worked out once at load, and colours worked out once per palette, so a rebuild is mostly drawing
    hidden var skyW as Array<Number> = [];     // per sky row: blend weight 0..256, +512 for the lower segment
    hidden var fadeW as Array<Number> = [];    // ground fade weights 0..256
    hidden var milky as Array<Number> = [];    // Milky Way dust: x, y, alpha triples
    hidden var skyRows as Array<Number> = [];
    hidden var skyKey as Number = -1;
    hidden var skyStrip as Graphics.BufferedBitmapReference or Null = null; // 1-px gradients, stretched across
    hidden var stripKey as Number = -1;
    hidden var fadeStrip as Graphics.BufferedBitmapReference or Null = null;
    hidden var fadeKey as Number = -1;
    hidden var roleCols as Array<Number> = new [11] as Array<Number>;

    function initialize() { }

    function load() as Void {
        fTime = WatchUi.loadResource(Rez.Fonts.TimeFont) as WatchUi.FontResource;
        fLine = WatchUi.loadResource(Rez.Fonts.TimeLine) as WatchUi.FontResource;
        fText = WatchUi.loadResource(Rez.Fonts.TextFont) as WatchUi.FontResource;
        fValue = WatchUi.loadResource(Rez.Fonts.ValueFont) as WatchUi.FontResource;
        fSmall = WatchUi.loadResource(Rez.Fonts.SmallFont) as WatchUi.FontResource;
        if (Graphics has :getVectorFont) {
            vLabel = Graphics.getVectorFont({:face => ["NotoSansSCMedium", "RobotoCondensedBold"], :size => 20});
        }
        shapes = [];
        for (var i = 0; i < Geo.SHAPES.size(); i++) { shapes.add(U.pts(Geo.SHAPES[i] as Array<Number>, 0, 0)); }
        // the stars with open sky behind them, worked out once so a frame only twinkles them
        stars = [];
        for (var i = 0; i < 60; i++) {
            var x = 40 + U.rnd(i, 1) * 374;
            var y = 26 + U.rnd(i, 2) * 150;
            if (!skyOpen(x, y)) { continue; }
            var b = U.rnd(i, 3);
            stars.addAll([x, y, b > 0.86 ? 1.6 : (b > 0.5 ? 1.1 : 0.8), b > 0.93 ? 0xFFF2D6 : 0xDFE8FF,
                          b > 0.86 ? 1 : 0.35 + b * 0.5, 1.3 + b * 2.2, i * 1.9]);
        }
        skyW = new [Geo.HORIZON] as Array<Number>;
        for (var y = 0; y < Geo.HORIZON; y++) {
            skyW[y] = y < 120 ? (256 * Math.pow(y / 120.0, 1.3)).toNumber()
                              : 512 + (256 * Math.pow((y - 120) / (Geo.HORIZON - 120.0), 1.7)).toNumber();
        }
        fadeW = new [36] as Array<Number>;
        for (var i = 0; i < 36; i++) { fadeW[i] = (256 * Math.pow(i / 36.0, 0.6)).toNumber(); }
        milky = [];
        for (var i = 0; i < 90; i++) {
            var k = U.rnd(i, 61);
            var x = 40 + k * 380;
            var yc = k < 0.42 ? 150 - k / 0.42 * 90 : 60 - (k - 0.42) / 0.58 * 40;
            var y = yc + (U.rnd(i, 62) - 0.5) * 38;
            if (skyOpen(x, y)) { milky.add(x.toNumber()); milky.add(y.toNumber()); milky.add((60 + 90 * U.rnd(i, 63)).toNumber()); }
        }
    }

    // integer blend, w = 0..256
    static function imix(a as Number, b as Number, w as Number) as Number {
        var v = 256 - w;
        return ((((a >> 16) & 255) * v + ((b >> 16) & 255) * w) >> 8) << 16
             | ((((a >> 8) & 255) * v + ((b >> 8) & 255) * w) >> 8) << 8
             | (((a & 255) * v + (b & 255) * w) >> 8);
    }

    // ------------------------------------------------------------ frame
    function draw(dc as Graphics.Dc, m as Model, intro as Float, t as Float, meteorAt as Float) as Void {
        prepare(m);
        rebuilt = false;
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var e = U.ease(intro);
        var rich = m.motion == 0;
        var drift = rich ? t : 0.0;
        prof(null);
        if (!blitCache(dc, m, intro, e, day && rich)) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
            drawLandLayer(dc);
            drawTextLayer(dc, m, e);
        }
        prof("b_copy");
        drawClouds(dc, ([0.0, 0.35, 0.8, 0.9, 0.75, 0.3, 1.0] as Array<Float>)[fx], drift);
        if (fx == 5) { drawFog(dc, drift); }
        prof("d_clouds");
        drawStars(dc, t, rich, e);
        prof("d_stars");
        if (meteorAt >= 0 && starA > 0.5 && rich) { drawMeteor(dc, meteorAt, t); }
        if (slots.size() > 0) { drawFireworks(dc, t, rich); }
        if (fest == 2) { drawSkyLanterns(dc, t, rich); }
        if (fest == 5) { drawBats(dc, t); }
        if (fest > 0) { Ev.motion(dc, self, t, rich); }
        if (fest == 14 && fx < 3) { drawRain(dc, t, rich, false); } // 清明 drizzle
        if (day && fx < 2 && rich && fest == 0) { drawBirds(dc, t); }
        if (!day || (m.temp != null && m.temp < 12)) { drawSmoke(dc, t, rich); }
        if (stress) { drawVolcano(dc, t, rich); }
        if (lowBattery) { drawBolt(dc, t, rich); }
        if (fx == 3 || fx == 6) { drawRain(dc, t, rich, fx == 6); }
        if (fx == 4 || (fest == 4 && fx < 3)) { drawSnow(dc, t, rich); }
        if (fx == 6 && rich) { drawStorm(dc, t); }
        prof("d_fx");
        Hud.pulse(dc, self, m, rich ? t : -1.0);
        prof("d_pulse");
        if (!ringBaked) {
            drawSkyRing(dc, e, rich ? t : -1.0, true);
            drawGauges(dc, m, e);
        } else if (day && rich) {
            drawSun(dc, 1.0, t);
        }
        prof("d_ring");
        Hud.seconds(dc, self, m);
        prof("d_sec");
        if (intro < 0.6) {
            dc.setFill(U.argb(255 * (1 - intro / 0.6), 0));
            dc.fillRectangle(0, 0, 454, 454);
        }
        prof("d_fade");
    }

    // a full-screen off-screen bitmap, allocated again if the system purged it; null when none can be had
    hidden function surface(ref as Graphics.BufferedBitmapReference or Null) as Graphics.BufferedBitmapReference or Null {
        if (ref != null && (ref as Graphics.BufferedBitmapReference).get() != null) { return ref; }
        try {
            return Graphics.createBufferedBitmap({:width => 454, :height => 454});
        } catch (ex) {
            return null;
        }
    }

    hidden function layerDc(ref as Graphics.BufferedBitmapReference) as Graphics.Dc {
        var bdc = (ref.get() as Graphics.BufferedBitmap).getDc();
        if (bdc has :setAntiAlias) { bdc.setAntiAlias(true); }
        bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        bdc.clear();
        return bdc;
    }

    // paints the still layers into dc, repainting each only when it changed; false if no bitmap could be had.
    // During the intro the text is drawn every frame (counting up) and the landscape rises into place.
    // sunLive: the sun is left out of the cached ring and drawn every frame.
    hidden function blitCache(dc as Graphics.Dc, m as Model, intro as Float, e as Float, sunLive as Boolean) as Boolean {
        ringBaked = false;
        if (cacheFailed) { return false; }
        var l = surface(land);
        if (l == null) { cacheFailed = true; return false; }
        if (l != land) { land = l; landKey = -1; }
        if (landKey != landSig) {
            rebuilt = true;
            drawLandLayer(layerDc(l));
            landKey = landSig;
            cacheKey = -1;
        }
        var live = intro < 1.0;
        var c = surface(cache);
        if (c != cache) { cache = c; cacheKey = -1; }
        // the per-minute layer is repainted ahead, on the intro's first frame while the screen is still dark (the
        // view restarts the intro clock after it), so the hand-over to the ambient motion doesn't stall
        if (c != null && (cacheKey != rev || cacheSun != sunLive) && (!live || intro < 0.3)) {
            rebuilt = true;
            var cdc = layerDc(c);
            cdc.drawBitmap(0, 0, l);
            prof("c_land");
            drawTextLayer(cdc, m, 1.0);
            drawSkyRing(cdc, 1.0, -1.0, !sunLive);
            drawGauges(cdc, m, 1.0);
            prof("c_ring");
            cacheKey = rev;
            cacheSun = sunLive;
        }
        if (live) {
            var dy = (26 * (1 - e) + 0.5).toNumber();
            if (dy > 0) {
                var split = Geo.HORIZON + 36;
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
                dc.clear();
                dc.setClip(0, 0, 454, split);
                dc.drawBitmap(0, dy, l);
                dc.setClip(0, split, 454, 454 - split);
                dc.drawBitmap(0, 0, l);
                dc.clearClip();
            } else {
                dc.drawBitmap(0, 0, l);
            }
            prof("i_land");
            drawTextLayer(dc, m, e);
            return true;
        }
        if (c == null) { // only one bitmap to spare: draw the text every frame
            dc.drawBitmap(0, 0, l);
            drawTextLayer(dc, m, 1.0);
            return true;
        }
        dc.drawBitmap(0, 0, c);
        ringBaked = true;
        return true;
    }

    // sky and landscape: everything that changes only with the light, the weather or the day
    hidden function drawLandLayer(dc as Graphics.Dc) as Void {
        prof(null);
        drawSky(dc);
        prof("s_sky");
        if (starA > 0.3) { drawMilkyWay(dc, starA * (fullMoon ? 0.6 : 1)); }
        if (aurora) { drawAurora(dc, starA); }
        if (goal && day && fx < 3) { drawRainbow(dc, 1 - overcast); }
        if (fullMoon) { drawGlow(dc, 227, 110, 40, 0xC8D8FF, 0.35); }
        Ev.sky(dc, self);
        prof("s_skyfx");
        drawLand(dc);
        prof("s_land");
        drawGroundFade(dc);
        if (fx == 5) { haze(dc, pal[Pal.HOR], 90, 215, 0, 120); }
        prof("s_fade");
        drawRimShade(dc);
        prof("s_rim");
        drawGaugeTracks(dc);
        prof("s_ring");
    }

    // the text and the labels along the ring; e < 1 while the intro counts the numbers up
    hidden function drawTextLayer(dc as Graphics.Dc, m as Model, e as Float) as Void {
        var steps = m.steps == null ? "--" : (m.steps * e + 0.5).toNumber().toString();
        var body = m.bodyBattery == null ? "--" : (m.bodyBattery * e + 0.5).toNumber().toString();
        Hud.radial(dc, self, "STEP " + steps, 234, U.mix(accent, 0xFFFFFF, 0.2));
        Hud.radial(dc, self, "BODY " + body, 306, 0x8FD6C6);
        prof("t_radial");
        Hud.draw(dc, self, m, e);
        prof("t_read");
    }

    // sun state, palette and the calendar's choice of scene; recomputed about once a minute
    hidden function prepare(m as Model) as Void {
        if (m.revision == rev) { return; }
        rev = m.revision;
        var now = m.hour * 3600 + m.min * 60 + m.sec;
        var rise = m.sunrise;
        var set = m.sunset;
        var evening;
        if (now >= rise && now <= set) {
            alt = (52 * Math.sin(Math.PI * (now - rise) / (set - rise))).toFloat();
            evening = now > (rise + set) / 2;
            f = (now - rise).toFloat() / (set - rise);
        } else {
            var mins = (now > set ? now - set : rise - now) / 60.0;
            alt = (-mins * 0.22).toFloat();
            evening = now > set;
            f = ((now - set + 86400) % 86400).toFloat() / (86400 - (set - rise));
        }
        // whole degrees: the landscape layer is repainted only when the light has visibly changed
        alt = (alt + (alt < 0 ? -0.5 : 0.5)).toNumber().toFloat();
        if (m.sky == 1) { alt = -1.0; evening = false; f = 0.04; }
        else if (m.sky == 2) { alt = 30.0; f = 0.4; }
        else if (m.sky == 3) { alt = 2.5; evening = true; f = 0.95; }
        else if (m.sky == 4) { alt = -30.0; f = 0.7; }
        day = alt > -4;
        fx = m.weatherFx ? m.weatherClass : 0;
        var oc = [0.0, 0.15, 0.7, 0.85, 0.6, 0.55, 0.95] as Array<Float>;
        overcast = oc[fx];
        fest = m.festivals ? Ev.of(m.year, m.month, m.day) : 0;
        season = seasonOf(m.month);
        pal = Pal.compute(alt, evening, overcast, fx == 3 || fx == 6);
        festivalPalette();
        starA = (U.clamp((-alt - 3) / 9, 0, 1) * (1 - overcast)).toFloat();
        phase = moonPhase(m.year, m.month, m.day);
        accent = Lay.ACCENTS[m.accent < 0 || m.accent > 3 ? 0 : m.accent];
        goal = m.steps != null && m.stepGoal != null && m.stepGoal > 0 && m.steps >= m.stepGoal;
        stress = m.stress != null && m.stress >= m.stressLimit;
        lowBattery = m.battery <= m.batteryLimit || m.charging;
        slots = Ev.wantsFireworks(self) ? Ev.fireworkSlots(self) : [] as Array<Number>;
        fullMoon = !day && (phase - 0.5).abs() < 0.04 && fx < 2;
        aurora = !day && fx < 2 && season == 3 && fest == 0 && starA > 0.5;
        sunLeft = f < 0.5;
        lit = m.notifications > 0;
        for (var r = 0; r < 11; r++) { roleCols[r] = roleColor(r, sunLeft); }
        var key = pal[Pal.ZEN] ^ (pal[Pal.MID] * 31) ^ (pal[Pal.HOR] * 17);
        if (key != skyKey || skyRows.size() == 0) {
            skyKey = key;
            skyRows = new [Geo.HORIZON] as Array<Number>;
            var off5 = [0, 4, 2, 6] as Array<Number>;
            var off6 = [0, 2, 1, 3] as Array<Number>;
            for (var y = 0; y < Geo.HORIZON; y++) {
                var w = skyW[y];
                var c = w < 512 ? imix(pal[Pal.ZEN], pal[Pal.MID], w) : imix(pal[Pal.MID], pal[Pal.HOR], w - 512);
                // ordered dither: nudge each row before the 16-bit panel drops the low bits
                var o5 = off5[y & 3];
                var o6 = off6[y & 3];
                var rr = ((c >> 16) & 255) + o5;
                var gg = ((c >> 8) & 255) + o6;
                var bb = (c & 255) + o5;
                skyRows[y] = ((rr > 255 ? 255 : rr) << 16) | ((gg > 255 ? 255 : gg) << 8) | (bb > 255 ? 255 : bb);
            }
        }
        var sig = key;
        for (var r = 0; r < 11; r++) { sig = sig * 31 + roleCols[r]; }
        sig = ((sig * 31 + fx) * 31 + fest) * 31 + season;
        sig = sig * 31 + (stress ? 1 : 0) + (goal && day ? 2 : 0) + (fullMoon ? 4 : 0) + (aurora ? 8 : 0) + (lit ? 16 : 0) + (day ? 32 : 0);
        landSig = (sig * 31 + (starA * 20).toNumber()) * 31 + (overcast * 20).toNumber();
    }

    static function moonPhase(y as Number, m as Number, d as Number) as Float {
        var days = Cal.dayOfYear(y, m, d) - 1;
        for (var yy = 2000; yy < y; yy++) { days += Cal.isLeapYear(yy) ? 366 : 365; }
        // days since 2000-01-01 noon; reference new moon 2000-01-06 18:14 UT
        var p = (days - 5.26) / 29.530588853;
        p = p - Math.floor(p);
        return p.toFloat();
    }

    static function seasonOf(month as Number) as Number {
        if (month >= 3 && month <= 5) { return 0; }
        if (month >= 6 && month <= 8) { return 1; }
        if (month >= 9 && month <= 11) { return 2; }
        return 3;
    }

    // event days lean the sky colours towards their own hue
    hidden function festivalPalette() as Void {
        if (fest == 0) { return; }
        var k = fest * 4;
        var amount = Ev.SKY[k + 3] / 100.0;
        pal[Pal.ZEN] = U.mix(pal[Pal.ZEN], Ev.SKY[k], amount);
        pal[Pal.MID] = U.mix(pal[Pal.MID], Ev.SKY[k + 1], amount);
        pal[Pal.HOR] = U.mix(pal[Pal.HOR], Ev.SKY[k + 2], amount);
    }

    // ------------------------------------------------------------ sky
    // the sky fills the whole dial; it darkens towards the rim (drawRimShade). Rows come from prepare().
    hidden function drawSky(dc as Graphics.Dc) as Void {
        skyStrip = gradient(dc, skyStrip, stripKey != skyKey, skyRows, 0);
        stripKey = skyStrip != null ? skyKey : -1;
    }

    // draws a vertical gradient as one stretched 1-px strip; the strip is repainted only when its colours change.
    // Returns the strip (or null when bitmaps are unavailable, after drawing plain rows instead).
    hidden function gradient(dc as Graphics.Dc, strip as Graphics.BufferedBitmapReference or Null, stale as Boolean,
                             colors as Array<Number>, y0 as Number) as Graphics.BufferedBitmapReference or Null {
        if (!(Graphics has :createBufferedBitmap) || !(dc has :drawScaledBitmap)) {
            rows(dc, colors, y0);
            return null;
        }
        try {
            if (strip == null) { strip = Graphics.createBufferedBitmap({:width => 1, :height => colors.size()}); stale = true; }
            var bmp = (strip as Graphics.BufferedBitmapReference).get();
            if (bmp == null) { rows(dc, colors, y0); return null; }
            if (stale) {
                var sdc = (bmp as Graphics.BufferedBitmap).getDc();
                for (var y = 0; y < colors.size(); y++) {
                    sdc.setColor(colors[y], colors[y]);
                    sdc.drawPoint(0, y);
                }
            }
            dc.drawScaledBitmap(0, y0, 454, colors.size(), strip);
            return strip;
        } catch (ex) {
            rows(dc, colors, y0);
            return null;
        }
    }

    // full-width one-pixel rows; antialiasing is pointless for them and slow
    hidden function rows(dc as Graphics.Dc, colors as Array<Number>, y0 as Number) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(false); }
        for (var i = 0; i < colors.size(); i++) {
            dc.setFill(0xFF000000 | colors[i]);
            dc.fillRectangle(0, y0 + i, 454, 1);
        }
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
    }

    // moving things drawn over the cached layer may only use open sky
    static function skyOpen(x as Numeric, y as Numeric) as Boolean {
        if ((x - 227) * (x - 227) + (y - 227) * (y - 227) > 186 * 186) { return false; }
        return y < skylineAt(x) - 3;
    }

    static function skylineAt(x as Numeric) as Number {
        var i = ((x + 1) / 2).toNumber();
        if (i < 0) { i = 0; }
        if (i >= Geo.SKYLINE.size()) { i = Geo.SKYLINE.size() - 1; }
        return Geo.SKYLINE[i];
    }

    hidden function drawStars(dc as Graphics.Dc, t as Float, rich as Boolean, e as Float) as Void {
        if (starA <= 0.02) { return; }
        var a = 255 * starA * e;
        for (var k = 0; k < stars.size(); k += 7) {
            var tw = rich ? 0.55 + 0.45 * Math.sin(t * stars[k + 5] + stars[k + 6]) : 1.0;
            dc.setFill((((a * stars[k + 4] * tw).toNumber() & 255) << 24) | (stars[k + 3] as Number));
            dc.fillCircle(stars[k], stars[k + 1], stars[k + 2]);
        }
    }

    // the Milky Way: a faint diagonal band thick with dust-like stars (clear nights)
    hidden function drawMilkyWay(dc as Graphics.Dc, alpha as Float) as Void {
        var widths = [26, 15, 6] as Array<Number>;
        var alphas = [10, 12, 14] as Array<Number>;
        for (var j = 0; j < 3; j++) {
            var w = widths[j];
            dc.setFill(U.argb(alphas[j] * alpha, 0xB8C4E8));
            dc.fillPolygon([[40, 150 - w], [200, 60 - w], [420, 20 - w], [420, 20 + w], [200, 60 + w], [40, 150 + w]]);
        }
        for (var i = 0; i < milky.size(); i += 3) {
            dc.setFill(U.argb(milky[i + 2] * alpha, 0xE6ECFF));
            dc.fillCircle(milky[i], milky[i + 1], 0.7);
        }
    }

    // aurora on clear winter nights: three soft curtains
    hidden function drawAurora(dc as Graphics.Dc, alpha as Float) as Void {
        var colors = [0x5FE0A8, 0x48C8C0, 0x9A7AE0] as Array<Number>;
        for (var k = 0; k < 3; k++) {
            for (var j = 0; j < 3; j++) {
                var pts = new [26] as Array;
                for (var i = 0; i <= 12; i++) {
                    var x = 30 + i * 33;
                    var y = 70 + k * 18 + Math.sin(i * 0.7 + k * 1.3) * 16;
                    pts[i] = [x, y - 18 + k * 4 + j * 7];
                    pts[25 - i] = [x, y + 26];
                }
                dc.setFill(U.argb((16 + j * 8) * alpha, colors[k]));
                dc.fillPolygon(pts);
            }
        }
    }

    // faint discs read as a soft halo
    function drawGlow(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric, color as Number, strength as Numeric) as Void {
        for (var i = 6; i >= 1; i--) {
            dc.setFill(U.argb(255 * strength * 0.045 * (1 + (6 - i) * 0.3), color));
            dc.fillCircle(x, y, r * (1 + i * 0.7));
        }
    }

    // soft wisps drifting across the sky, lit on top and shadowed below; they fade near the rim so a cloud can wrap round unseen
    hidden function drawClouds(dc as Graphics.Dc, amount as Float, drift as Float) as Void {
        if (amount <= 0) { return; }
        var n = (2 + amount * 4 + 0.5).toNumber();
        var lit2 = U.mix(pal[Pal.GLOW], 0xFFFFFF, 0.5);
        var dark = U.mix(pal[Pal.RIDGE], pal[Pal.MID], 0.4);
        var a = 40 + amount * 50;
        for (var i = 0; i < n; i++) {
            var w = 60 + U.rnd(i, 11) * 70;
            var y = 44 + U.rnd(i, 12) * 76;
            var x = 60 + Ev.wrap(40 + U.rnd(i, 13) * 254 + drift * (4 + U.rnd(i, 14) * 6), 334);
            var k = U.clamp((212 - Math.sqrt((x - 227) * (x - 227) + (y - 227) * (y - 227)) - w * 0.25) / 40.0, 0, 1);
            if (k <= 0) { continue; }
            dc.setFill(U.argb(a * 0.8 * k, dark));
            dc.fillEllipse(x + w * 0.06, y + 5, w * 0.46, 4.5);
            dc.setFill(U.argb(a * k, lit2));
            dc.fillEllipse(x, y, w * 0.5, 4);
            dc.fillEllipse(x - w * 0.12, y - 3, w * 0.3, 4.5);
            dc.fillEllipse(x + w * 0.2, y + 1, w * 0.24, 3.5);
        }
    }

    // fog banks swaying slowly across the valley
    hidden function drawFog(dc as Graphics.Dc, drift as Float) as Void {
        var c = U.mix(pal[Pal.HOR], 0xFFFFFF, 0.35);
        for (var k = 0; k < 3; k++) {
            var x = 227 + Math.sin(drift * (0.12 + k * 0.05) + k * 2.1) * 80;
            var y = 150 + k * 22;
            dc.setFill(U.argb(34, c));
            dc.fillEllipse(x, y, 110 - k * 12, 10);
            dc.setFill(U.argb(26, c));
            dc.fillEllipse(x + 30, y - 4, 70, 7);
        }
    }

    // daytime goal reached: a bow behind the peak
    hidden function drawRainbow(dc as Graphics.Dc, alpha as Numeric) as Void {
        var colors = [0xE0766C, 0xEAB85F, 0x8FBF8E, 0x74B6CF] as Array<Number>;
        dc.setPenWidth(4);
        for (var i = 0; i < 4; i++) {
            dc.setStroke(U.argb(130 * alpha, colors[i]));
            dc.drawArc(227, 220, 150 - i * 4, Graphics.ARC_CLOCKWISE, 165, 15);
        }
    }

    // ------------------------------------------------------------ landscape
    // vertical alpha gradient, one row at a time
    function haze(dc as Graphics.Dc, color as Number, y0 as Number, y1 as Number, a0 as Numeric, a1 as Numeric) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(false); }
        var step = (y1 - y0 + 9) / 10; // ten bands are smooth enough for haze
        for (var y = y0; y < y1; y += step) {
            dc.setFill(U.argb(a0 + (a1 - a0) * (y - y0 + step / 2) / (y1 - y0), color));
            dc.fillRectangle(0, y, 454, y + step > y1 ? y1 - y : step);
        }
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
    }

    static function lum(c as Number) as Float {
        return ((((c >> 16) & 255) * 0.3 + ((c >> 8) & 255) * 0.59 + (c & 255) * 0.11) / 255.0).toFloat();
    }

    // seasons recolour the near land: hills, ground, trees
    hidden function seasonTint(c as Number, slot as Number) as Number {
        var land = [[0x3D6A48, 0x1F3A26, 0x1A3020], [0x2C5A38, 0x163020, 0x10261A], [0x8A5A30, 0x3A2414, 0x4A2412],
                    [0xC8D4E0, 0xDFE7EF, 0x2A3440]][season] as Array<Number>;
        var amount = [0.32, 0.38, 0.34, 0.5][season] as Float;
        var target = (slot == 1 && season == 3) ? U.mix(land[1], pal[Pal.SNOWS], 0.5) : U.shade(land[slot], U.clamp(lum(c) * 2.4 + 0.25, 0.25, 1));
        return U.mix(c, target, amount);
    }

    // palette colour per landscape role; the lit and shaded snow faces swap when the sun crosses noon
    hidden function roleColor(role as Number, sunLeft as Boolean) as Number {
        var lit = pal[Pal.SNOWL];
        var shd = U.mix(pal[Pal.SNOWS], pal[Pal.ROCKS], 0.15);
        if (role == 0) { return U.mix(pal[Pal.FAR], pal[Pal.HOR], 0.18); }
        if (role == 1) { return U.mix(pal[Pal.FAR], pal[Pal.RIDGE], 0.55); }
        if (role == 2) { return U.mix(pal[Pal.ROCKS], pal[Pal.NEAR], 0.45); }
        if (role == 3) { return sunLeft ? lit : U.mix(lit, shd, 0.55); }
        if (role == 4) { return sunLeft ? shd : U.mix(shd, lit, 0.6); }
        if (role == 5) { return U.mix(sunLeft ? lit : shd, pal[Pal.ROCKS], 0.2); }
        if (role == 6) { return U.mix(sunLeft ? shd : lit, pal[Pal.ROCKS], 0.35); }
        if (role == 7) { return seasonTint(pal[Pal.RIDGE], 0); }
        if (role == 8) { return seasonTint(pal[Pal.NEAR], 1); }
        if (role == 10) { return U.shade(seasonTint(pal[Pal.RIDGE], 0), 0.7); }
        return seasonTint(U.shade(pal[Pal.NEAR], 0.55), 2);
    }

    hidden function drawLand(dc as Graphics.Dc) as Void {
        for (var i = 0; i < shapes.size(); i++) {
            var role = Geo.ROLES[i];
            dc.setFill(0xFF000000 | roleCols[role]);
            dc.fillPolygon(shapes[i] as Array);
            if (role == 1) { haze(dc, pal[Pal.HOR], 160, 202, 0, 70); }
            if (role == 6) { drawRidgeLight(dc, sunLeft); }
            if (role == 4 && stress) {
                dc.setFill(U.argb(255, 0xE88355));
                dc.fillPolygon(U.pts(Geo.LAVA, 0, 0));
            }
            if (role == 9 && season == 3) { // snow on the pine tops
                var top = (shapes[i] as Array)[0] as Array<Numeric>;
                dc.setFill(U.argb(255, U.mix(pal[Pal.SNOWS], 0xFFFFFF, 0.3)));
                dc.fillPolygon([[top[0], top[1]], [top[0] - 3, top[1] + 6], [top[0] + 3, top[1] + 6]]);
            }
        }
        drawSeasonDots(dc);
        Ev.land(dc, self);
        drawCabin(dc);
    }

    // a thin highlight along the ridges that face the sun
    hidden function drawRidgeLight(dc as Graphics.Dc, sunLeft as Boolean) as Void {
        var r = Geo.RIDGE;
        var segs = sunLeft ? [0, 1, 2, 3] : [3, 4, 5, 6];
        dc.setPenWidth(1.5);
        dc.setStroke(U.argb(150, U.mix(pal[Pal.SNOWL], 0xFFFFFF, 0.4)));
        for (var k = 0; k < 4; k += 2) {
            var a = segs[k];
            var b = segs[k + 1];
            dc.drawLine(r[2 * a], r[2 * a + 1], r[2 * b], r[2 * b + 1]);
        }
    }

    // spring blossom on the hills, autumn colour in the far pines
    hidden function drawSeasonDots(dc as Graphics.Dc) as Void {
        if (season != 0 && season != 2) { return; }
        var cols = season == 0 ? [0xF6B8C8, 0xFFD6E0] : [0xE0703A, 0xF0A040, 0xC84A2A];
        for (var i = 0; i < 22; i++) {
            var x = 20 + U.rnd(i, 91) * 414;
            var y = 176 + U.rnd(i, 92) * 30;
            var top = skylineAt(x) + 4;
            if (y < top) { y = top; }
            if (y > Geo.HORIZON - 2) { continue; }
            dc.setFill(U.argb(season == 0 ? 190 : 130, cols[i % cols.size()]));
            dc.fillCircle(x, y, 1.2 + U.rnd(i, 93));
        }
    }

    hidden function drawCabin(dc as Graphics.Dc) as Void {
        var house = roleCols[9];
        dc.setFill(U.argb(255, house));
        dc.fillPolygon(U.pts(Geo.CHIMNEY, 0, 0));
        dc.fillPolygon(U.pts(Geo.CABIN, 0, 0));
        dc.setFill(U.argb(255, U.mix(house, 0, 0.4)));
        dc.fillPolygon(U.pts(Geo.DOOR, 0, 0));
        dc.setFill(U.argb(255, lit ? 0xFFC66A : (!day ? 0x8A6A3A : U.mix(house, pal[Pal.RIDGE], 0.5))));
        dc.fillPolygon(U.pts(Geo.WINDOW, 0, 0));
        if (lit) { drawGlow(dc, 330, 197, 4, 0xFFB44A, 0.8); }
        Ev.cabin(dc, self);
    }

    // the ground melts into the black half instead of stopping on a hard line
    hidden function drawGroundFade(dc as Graphics.Dc) as Void {
        var base = roleCols[8];
        var cols = new [36] as Array<Number>;
        for (var i = 0; i < 36; i++) { cols[i] = imix(base, 0, fadeW[i]); }
        fadeStrip = gradient(dc, fadeStrip, fadeKey != base, cols, Geo.HORIZON);
        fadeKey = fadeStrip != null ? base : -1;
    }

    // the sky darkens towards the rim of the dial, the same kind of gradient as the ground below
    hidden function drawRimShade(dc as Graphics.Dc) as Void {
        dc.setPenWidth(8);
        for (var r = 178; r < 228; r += 8) {
            dc.setStroke(U.argb(230 * Math.pow((r - 174) / 54.0, 1.6), 0));
            dc.drawArc(227, 227, r + 4, Graphics.ARC_CLOCKWISE, 90, 270);
            dc.drawArc(227, 227, r + 4, Graphics.ARC_CLOCKWISE, 270, 90);
        }
    }

    // ------------------------------------------------------------ moving parts
    hidden function drawRain(dc as Graphics.Dc, t as Float, rich as Boolean, heavy as Boolean) as Void {
        dc.setStroke(U.argb(heavy ? 140 : 110, 0xC8D8EA));
        dc.setPenWidth(1.4);
        for (var i = 0; i < (heavy ? 44 : 30); i++) {
            var len = 10 + U.rnd(i, 22) * 12;
            var y = U.rnd(i, 24) * 200 + (rich ? t * (260 + U.rnd(i, 23) * 120) : 0);
            y = y - (y / 200).toNumber() * 200 + 20;
            var x = 60 + U.rnd(i, 21) * 360 - (y - 20) * 0.18;
            if (y < Geo.HORIZON - 8 && (x - 227) * (x - 227) + (y - 227) * (y - 227) < 190 * 190) {
                dc.drawLine(x, y, x - len * 0.18, y + len);
            }
        }
    }

    hidden function drawSnow(dc as Graphics.Dc, t as Float, rich as Boolean) as Void {
        for (var i = 0; i < 40; i++) {
            var y = U.rnd(i, 33) * 200 + (rich ? t * (18 + U.rnd(i, 31) * 22) : 0);
            y = y - (y / 196).toNumber() * 196 + 20;
            var x = 50 + U.rnd(i, 34) * 354 + (rich ? Math.sin(t * 0.9 + i) * 6 : 0);
            if ((x - 227) * (x - 227) + (y - 227) * (y - 227) < 190 * 190 && y < Geo.HORIZON) {
                dc.setFill(U.argb(150 + 100 * U.rnd(i, 35), 0xF4F8FF));
                dc.fillCircle(x, y, 0.9 + U.rnd(i, 32) * 1.6);
            }
        }
    }

    // a brief flash and a forked bolt
    hidden function drawStorm(dc as Graphics.Dc, t as Float) as Void {
        if (!((t > 1.1 && t < 1.25) || (t > 5.3 && t < 5.42))) { return; }
        dc.setFill(U.argb(55, 0xE8ECFF));
        dc.fillRectangle(0, 0, 454, Geo.HORIZON);
        var x0 = t < 3 ? 150 : 300;
        var pts = [[x0, 40], [x0 - 8, 70], [x0 + 4, 74], [x0 - 10, 110], [x0 + 2, 114], [x0 - 6, 150]] as Array<Array<Number> >;
        dc.setStroke(U.argb(240, 0xF4F6FF));
        dc.setPenWidth(2);
        for (var i = 0; i < 5; i++) { dc.drawLine(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]); }
        dc.setPenWidth(1);
        dc.drawLine(pts[2][0], pts[2][1], pts[2][0] + 14, pts[2][1] + 22);
    }

    hidden function drawMeteor(dc as Graphics.Dc, t0 as Float, t as Float) as Void {
        var k = (t - t0) / 0.7;
        if (k < 0 || k > 1) { return; }
        var x = 130 + k * 130;
        var y = 40 + k * 44;
        dc.setPenWidth(2);
        for (var i = 0; i < 8; i++) {
            dc.setStroke(U.argb(220 * (1 - i / 8.0) * Math.sin(Math.PI * k), 0xFFFFFF));
            dc.drawLine(x - i * 7, y - i * 2.4, x - (i + 1) * 7, y - (i + 1) * 2.4);
        }
    }

    // night-time goal, new year and new year's eve; Ev.fireworkSlots keeps the bursts clear of the rest of the sky
    hidden function drawFireworks(dc as Graphics.Dc, t as Float, rich as Boolean) as Void {
        var colors = [0xFFD36A, 0xFF7AA8, 0x8FD0FF] as Array<Number>;
        for (var k = 0; k < slots.size() / 2; k++) {
            var bx = slots[2 * k];
            var by = slots[2 * k + 1];
            var ph = (rich ? t : 1.0) + k * 0.55;
            ph = (ph - (ph / 1.6).toNumber() * 1.6) / 1.6;
            var r = 4 + ph * 22;
            var a = 230 * (1 - ph);
            dc.setFill(U.argb(a, colors[k]));
            for (var i = 0; i < 12; i++) {
                var an = i * Math.PI / 6 + k;
                dc.fillCircle(bx + Math.cos(an) * r, by + Math.sin(an) * r + ph * ph * 6, 1.6);
            }
            dc.setFill(U.argb(a * 0.35, colors[k]));
            dc.fillCircle(bx, by, r * 0.35);
        }
    }

    // 元宵: paper lanterns drifting up
    hidden function drawSkyLanterns(dc as Graphics.Dc, t as Float, rich as Boolean) as Void {
        for (var i = 0; i < 6; i++) {
            var ph = (rich ? t * 0.06 : 0.4) + U.rnd(i, 71);
            ph = ph - ph.toNumber();
            var x = 80 + U.rnd(i, 72) * 300 + Math.sin(ph * 6 + i) * 6;
            var y = 200 - ph * 170;
            if (!skyOpen(x, y) && y > 100) { continue; }
            var a = 230 * U.clamp((1 - ph) * 3, 0, 1);
            var fl = rich ? 0.8 + 0.2 * Math.sin(t * 9 + i * 3) : 1;
            drawGlow(dc, x, y, 3, 0xFFA040, 0.6 * fl);
            dc.setFill(U.argb(a, 0xFFB050));
            dc.fillRoundedRectangle(x - 3, y - 4, 6, 8, 2);
        }
    }

    // 万圣: bats flitting across the sky
    hidden function drawBats(dc as Graphics.Dc, t as Float) as Void {
        dc.setFill(U.argb(255, 0x140A18));
        for (var i = 0; i < 4; i++) {
            var x = t * (14 + i * 4) + i * 90;
            x = x - (x / 330).toNumber() * 330 + 60;
            var y = 60 + i * 14 + Math.sin(t * 2 + i) * 8;
            var w = 6 + Math.sin(t * 12 + i) * 3;
            dc.fillPolygon([[x - 9, y - w * 0.4], [x - 4, y], [x - 2, y - 2], [x, y + 2], [x + 2, y - 2], [x + 4, y], [x + 9, y - w * 0.4],
                            [x + 3, y + 3], [x, y + 5], [x - 3, y + 3]]);
        }
    }

    // a small flock in a loose V gliding across a fair-weather day
    hidden function drawBirds(dc as Graphics.Dc, t as Float) as Void {
        var lx = 64 + t * 26;
        var ly = 104 - t * 2 + Math.sin(t * 0.7) * 4;
        dc.setStroke(U.argb(200, 0x22303C));
        dc.setPenWidth(1.4);
        for (var i = 0; i < 5; i++) {
            var row = (i + 1) / 2;
            var x = lx - row * 11;
            var y = ly + (i % 2 == 1 ? -1 : 1) * row * 7 + Math.sin(t * 1.7 + i) * 1.5;
            if ((x - 227) * (x - 227) + (y - 227) * (y - 227) > 186 * 186) { continue; }
            var flap = Math.sin(t * 8 + i * 1.3) * 2.6;
            dc.drawLine(x - 5, y - 1 - flap, x, y + 1);
            dc.drawLine(x, y + 1, x + 5, y - 1 - flap);
        }
    }

    // the cabin chimney on cold days and at night
    hidden function drawSmoke(dc as Graphics.Dc, t as Float, rich as Boolean) as Void {
        var x0 = Geo.SMOKE[0];
        var y0 = Geo.SMOKE[1];
        for (var i = 0; i < 5; i++) {
            var ph = (rich ? t * 0.35 : 0.3) + i / 5.0;
            ph = ph - ph.toNumber();
            dc.setFill(U.argb(110 * (1 - ph), 0xC8CCD4));
            dc.fillCircle(x0 + ph * 14 + Math.sin(ph * 6 + i) * 2, y0 - ph * 34, 2 + ph * 5);
        }
    }

    // stress above the threshold: sparks over the summit
    hidden function drawVolcano(dc as Graphics.Dc, t as Float, rich as Boolean) as Void {
        var x0 = Geo.APEX[0];
        var y0 = Geo.APEX[1];
        drawGlow(dc, x0 - 2, y0 + 6, 6, 0xFF7A3A, 0.9);
        for (var i = 0; i < 8; i++) {
            var ph = (rich ? t * 0.9 : 0.5) + U.rnd(i, 51);
            ph = ph - ph.toNumber();
            dc.setFill(U.argb(240 * (1 - ph), 0xFF9B45));
            dc.fillCircle(x0 + (U.rnd(i, 52) - 0.5) * 30 * ph, y0 - 4 - ph * 30, 1.8 * (1 - ph) + 0.6);
        }
    }

    // low battery or charging: lightning in the sky, flickering when motion is on
    hidden function drawBolt(dc as Graphics.Dc, t as Float, rich as Boolean) as Void {
        var c = t - (t / 2.2).toNumber() * 2.2;
        if (rich && c > 1.4 && c < 1.6) { return; }
        dc.setFill(U.argb(255, 0xF8CC68));
        dc.fillPolygon(U.pts(Geo.BOLT, 0, 0));
        drawGlow(dc, 349, 83, 7, 0xF8CC68, 0.5);
    }

    // ------------------------------------------------------------ ring
    hidden function cap(dc as Graphics.Dc, angle as Numeric, r as Numeric) as Void {
        var p = U.ringPoint(angle, Lay.RING_R);
        dc.fillCircle(p[0], p[1], r);
    }

    // upper half: the day (or night) from horizon to horizon with the sun or moon riding it;
    // a rainbow ring once the day's step goal is met. body false: the sun or moon is left to drawSun.
    hidden function drawSkyRing(dc as Graphics.Dc, e as Float, t as Float, body as Boolean) as Void {
        var alpha = 1 - overcast * 0.6;
        var a0 = Lay.SUN_SPAN[0];
        var a1 = Lay.SUN_SPAN[1];
        var pos = a0 - (a0 - a1) * U.clamp(f, 0, 1) * e;
        if (goal && day) {
            var colors = [0xE0766C, 0xEAB85F, 0x8FBF8E, 0x74B6CF] as Array<Number>;
            dc.setPenWidth(2);
            for (var i = 0; i < 4; i++) {
                dc.setStroke(U.argb(200, colors[i]));
                dc.drawArc(227, 227, Lay.RING_R + 4 - i * 2.5, Graphics.ARC_CLOCKWISE, a0, a1);
            }
        } else {
            dc.setPenWidth(2);
            dc.setStroke(U.argb(80, 0xFFFFFF));
            dc.drawArc(227, 227, Lay.RING_R, Graphics.ARC_CLOCKWISE, a0, a1);
        }
        if (f * e > 0.005) {
            dc.setPenWidth(3);
            dc.setStroke(U.argb(230 * alpha, day ? 0xFFD28A : 0xBFD0FF));
            dc.drawArc(227, 227, Lay.RING_R, Graphics.ARC_CLOCKWISE, a0, pos);
        }
        dc.setStroke(U.argb(160, 0xFFFFFF));
        dc.setPenWidth(1.5);
        var ticks = [a0, 90, a1] as Array<Number>;
        for (var i = 0; i < 3; i++) {
            var p1 = U.ringPoint(ticks[i], Lay.RING_R - 5);
            var p2 = U.ringPoint(ticks[i], Lay.RING_R + 5);
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
        if (body) { drawSun(dc, e, t); }
    }

    // the sun, its halo breathing while t >= 0, or the moon, at its place on the ring
    hidden function drawSun(dc as Graphics.Dc, e as Float, t as Float) as Void {
        var alpha = 1 - overcast * 0.6;
        var a0 = Lay.SUN_SPAN[0];
        var p = U.ringPoint(a0 - (a0 - Lay.SUN_SPAN[1]) * U.clamp(f, 0, 1) * e, Lay.RING_R);
        if (day) {
            drawGlow(dc, p[0], p[1], 8, pal[Pal.GLOW], alpha * (t >= 0 ? 0.8 + 0.25 * Math.sin(t * 2.2) : 1));
            dc.setFill(U.argb(255 * (alpha > 0.4 ? alpha : 0.4), pal[Pal.SUN]));
            dc.fillCircle(p[0], p[1], 8);
        } else {
            drawMoon(dc, p[0], p[1], alpha > 0.45 ? alpha : 0.45);
        }
    }

    // moon with its real phase; a full moon gets a larger disc and a brighter halo
    hidden function drawMoon(dc as Graphics.Dc, x as Numeric, y as Numeric, alpha as Numeric) as Void {
        var r = fullMoon ? 9 : 8;
        var k = Math.cos(phase * 2 * Math.PI);
        var dir = phase < 0.5 ? 1 : -1;
        drawGlow(dc, x, y, r, fullMoon ? 0xD8E4FF : 0x9DB4E0, alpha * (fullMoon ? 1.2 : 0.5));
        dc.setFill(U.argb(255, U.mix(pal[Pal.ZEN], 0x3A4660, 0.6)));
        dc.fillCircle(x, y, r);
        var lit = new [34] as Array;
        for (var i = 0; i <= 16; i++) {
            var an = -Math.PI / 2 + Math.PI * i / 16;
            lit[i] = [x + dir * r * Math.cos(an), y + r * Math.sin(an)];
            lit[33 - i] = [x + dir * r * k * Math.cos(an), y + r * Math.sin(an)];
        }
        dc.setFill(U.argb(255 * alpha, 0xEEF2F8));
        dc.fillPolygon(lit);
    }

    // lower half: steps (left) and body battery (right) climb the ring from the bottom; labels follow the ring
    hidden function drawGaugeTracks(dc as Graphics.Dc) as Void {
        dc.setPenWidth(5);
        dc.setStroke(U.argb(255, Lay.TRACK));
        dc.setFill(U.argb(255, Lay.TRACK));
        dc.drawArc(227, 227, Lay.RING_R, Graphics.ARC_CLOCKWISE, Lay.STEPS[0], Lay.STEPS[1]);
        dc.drawArc(227, 227, Lay.RING_R, Graphics.ARC_COUNTER_CLOCKWISE, Lay.BODY[0], Lay.BODY[1]);
        cap(dc, Lay.STEPS[0], 2.5);
        cap(dc, Lay.STEPS[1], 2.5);
        cap(dc, Lay.BODY[0], 2.5);
        cap(dc, Lay.BODY[1], 2.5);
    }

    hidden function gauge(dc as Graphics.Dc, span as Array<Number>, value as Float, color as Number, e as Float, clockwise as Boolean) as Void {
        if (value <= 0 || e <= 0) { return; }
        var a0 = span[0];
        var end = a0 + (clockwise ? -1 : 1) * (span[1] - a0).abs() * U.clamp(value, 0, 1) * e;
        dc.setPenWidth(5);
        dc.setStroke(U.argb(255, color));
        dc.drawArc(227, 227, Lay.RING_R, clockwise ? Graphics.ARC_CLOCKWISE : Graphics.ARC_COUNTER_CLOCKWISE, a0, end);
        dc.setFill(U.argb(255, color));
        cap(dc, a0, 2.5);
        cap(dc, end, 2.5);
        dc.setFill(U.argb(70, color));
        cap(dc, end, 6);
    }

    hidden function drawGauges(dc as Graphics.Dc, m as Model, e as Float) as Void {
        var sp = (m.steps == null || m.stepGoal == null || m.stepGoal == 0) ? 0.0 : m.steps.toFloat() / m.stepGoal;
        gauge(dc, Lay.STEPS, sp, sp >= 1 ? U.mix(accent, 0xFFFFFF, 0.3) : accent, e, true);
        var bb = m.bodyBattery == null ? 0.0 : m.bodyBattery / 100.0;
        gauge(dc, Lay.BODY, bb, bb < 0.25 ? 0xFF7A66 : 0x5FD3BD, e, false);
    }

    // ------------------------------------------------------------ always-on
    // the whole scene in fine line art, a few percent of pixels lit, shifted every minute
    function drawAod(dc as Graphics.Dc, m as Model) as Void {
        prepare(m);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        var shifts = [[0, 0], [4, 3], [-3, 5], [5, -3], [-4, -4]] as Array<Array<Number> >;
        var dx = shifts[m.min % 5][0];
        var dy = shifts[m.min % 5][1];
        // dotted sun path with the sun or moon as a small ring
        var a0 = Lay.SUN_SPAN[0];
        var a1 = Lay.SUN_SPAN[1];
        dc.setFill(U.argb(255, 0x2A3038));
        for (var a = a0; a >= a1; a -= 6) {
            var p = U.ringPoint(a, Lay.RING_R);
            dc.fillCircle(p[0] + dx, p[1] + dy, 1);
        }
        var sp = U.ringPoint(a0 - (a0 - a1) * U.clamp(f, 0, 1), Lay.RING_R);
        dc.setStroke(U.argb(255, day ? 0x8A6A3A : 0x6A7A9A));
        dc.setPenWidth(1.5);
        dc.drawCircle(sp[0] + dx, sp[1] + dy, 5);
        // a scatter of faint stars
        dc.setFill(U.argb(255, 0x3A4250));
        for (var i = 0; i < 16; i++) {
            var x = 60 + U.rnd(i, 81) * 334;
            var y = 40 + U.rnd(i, 82) * 110;
            if (skyOpen(x, y)) { dc.fillCircle(x + dx, y + dy, 0.8); }
        }
        // the landscape as line art
        outline(dc, Geo.FAR_RIDGE, 0x232A33, false, dx, dy);
        for (var i = 0; i < Geo.SHAPES.size(); i++) {
            var role = Geo.ROLES[i];
            var flat = Geo.SHAPES[i] as Array<Number>;
            if (role == 2) { outline(dc, flat, 0x3C4856, false, dx, dy); }
            else if (role == 3 || role == 4) { outline(dc, flat, 0x56606C, true, dx, dy); }
            else if (role == 9 && flat[1] < 200) { outline(dc, flat, 0x262D36, true, dx, dy); }
        }
        outline(dc, Geo.CABIN, 0x34404C, true, dx, dy);
        if (m.notifications > 0) {
            dc.setFill(U.argb(255, 0x7A5A2A));
            dc.fillPolygon(U.pts(Geo.WINDOW, dx, dy));
        }
        dc.setStroke(U.argb(255, 0x1C2128));
        dc.setPenWidth(1);
        dc.drawLine(70 + dx, Geo.HORIZON + 2 + dy, 384 + dx, Geo.HORIZON + 2 + dy);
        Hud.aod(dc, self, m, dx, dy);
    }

    hidden function outline(dc as Graphics.Dc, flat as Array<Number>, color as Number, close as Boolean, dx as Number, dy as Number) as Void {
        dc.setStroke(U.argb(255, color));
        dc.setPenWidth(1);
        var n = flat.size() / 2;
        for (var i = 0; i < (close ? n : n - 1); i++) {
            var j = (i + 1) % n;
            dc.drawLine(flat[2 * i] + dx, flat[2 * i + 1] + dy, flat[2 * j] + dx, flat[2 * j + 1] + dy);
        }
    }
}
