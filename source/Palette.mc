import Toybox.Lang;

// Sky and landscape colours keyed by an approximate sun altitude in degrees.
// The same table lives in preview-render.js (KEYS / EVENING).
module Pal {
    enum { ZEN, MID, HOR, FAR, ROCKL, ROCKS, SNOWL, SNOWS, RIDGE, NEAR, WATER, SUN, GLOW }

    const KEY_ALT = [-14.0, -6.0, -1.5, 3.0, 10.0, 26.0];
    const KEYS = [
        //  zenith    sky-mid   horizon   far       rock-lit  rock-shd  snow-lit  snow-shd  ridge     near      water     sun       glow
        [0x050A17, 0x0B1730, 0x1B2C4A, 0x1D2C49, 0x18253D, 0x111B2F, 0x9FB2CF, 0x4B5C7C, 0x0E1727, 0x060B15, 0x0A1426, 0xEEF2F8, 0x8FA8D8],
        [0x0C1836, 0x26376A, 0x5A6294, 0x3C4573, 0x2D375A, 0x212A49, 0xB4BAE0, 0x6670A0, 0x1B2242, 0x0B1021, 0x1A2242, 0xFFD2B0, 0xC8A8C8],
        [0x1A2C5A, 0x4F5188, 0xE5937C, 0x6A6490, 0x5A4B6C, 0x3A395F, 0xF7C0AC, 0x8C84AD, 0x2B2947, 0x121229, 0x3A3456, 0xFFB27A, 0xFFA070],
        [0x274474, 0x6D76A2, 0xF2B06C, 0x8A829E, 0x8A5F50, 0x4A4666, 0xFFCF8A, 0x9A8FB2, 0x38334E, 0x181627, 0x4C4560, 0xFFD59A, 0xFFB060],
        [0x24548C, 0x5A88B8, 0xD9D6C4, 0x8797B2, 0x6C6A74, 0x4A5472, 0xFFF3E0, 0xA0ADCA, 0x33405A, 0x152030, 0x3C5270, 0xFFF4D8, 0xFFE0A0],
        [0x184F8C, 0x3E7CB4, 0xA9CCE0, 0x86A6C2, 0x5D6D80, 0x42536D, 0xFAFCFF, 0xA6BCD6, 0x2C4357, 0x13212F, 0x2E4B65, 0xFFFBE8, 0xFFF0C0]
    ];

    // evenings are warmer than mornings: only horizon, lit snow and glow change
    function keyColor(k as Number, i as Number, evening as Boolean) as Number {
        if (evening && k == 2) {
            if (i == HOR) { return 0xD9706E; }
            if (i == SNOWL) { return 0xF2A59A; }
            if (i == GLOW) { return 0xFF7F6A; }
        }
        if (evening && k == 3) {
            if (i == HOR) { return 0xF0965A; }
            if (i == SNOWL) { return 0xFFBE78; }
            if (i == GLOW) { return 0xFF9A50; }
        }
        return (KEYS[k] as Array<Number>)[i];
    }

    function compute(alt as Float, evening as Boolean, overcast as Float, wet as Boolean) as Array<Number> {
        var last = KEY_ALT.size() - 1;
        var k = 0;
        var t = 0.0;
        if (alt >= KEY_ALT[last]) {
            k = last - 1;
            t = 1.0;
        } else if (alt > KEY_ALT[0]) {
            while (alt > KEY_ALT[k + 1]) { k += 1; }
            t = (alt - KEY_ALT[k]) / (KEY_ALT[k + 1] - KEY_ALT[k]);
        }
        var p = new [13] as Array<Number>;
        for (var i = 0; i < 13; i++) {
            var c = U.mix(keyColor(k, i, evening), keyColor(k + 1, i, evening), t);
            if (overcast > 0 && i != SUN && i != GLOW) { c = U.mix(c, U.grey(c), overcast * 0.8); }
            if (wet && i <= HOR) { c = U.shade(c, 0.82); }
            p[i] = c;
        }
        return p;
    }
}
