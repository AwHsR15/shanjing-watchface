import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Small helpers shared by the renderer. preview-render.js has the same functions.
module U {
    function argb(a as Numeric, rgb as Number) as Number {
        return ((a.toNumber() & 255) << 24) | (rgb & 0xFFFFFF);
    }

    function mix(a as Number, b as Number, t as Numeric) as Number {
        if (t <= 0) { return a; }
        if (t >= 1) { return b; }
        var r = ((a >> 16) & 255) + ((((b >> 16) & 255) - ((a >> 16) & 255)) * t);
        var g = ((a >> 8) & 255) + ((((b >> 8) & 255) - ((a >> 8) & 255)) * t);
        var bl = (a & 255) + (((b & 255) - (a & 255)) * t);
        return ((r + 0.5).toNumber() << 16) | ((g + 0.5).toNumber() << 8) | (bl + 0.5).toNumber();
    }

    function shade(c as Number, k as Numeric) as Number { return mix(0, c, k); }

    function grey(c as Number) as Number {
        var l = (((c >> 16) & 255) * 0.3 + ((c >> 8) & 255) * 0.59 + (c & 255) * 0.11).toNumber();
        return mix((l << 16) | (l << 8) | l, 0x8090A0, 0.25);
    }

    function clamp(v as Numeric, a as Numeric, b as Numeric) as Numeric {
        return v < a ? a : (v > b ? b : v);
    }

    function ease(t as Numeric) as Float {
        var u = 1.0 - clamp(t, 0, 1);
        return 1.0 - u * u * u;
    }

    // deterministic hash noise in [0,1]; integer maths wraps at 32 bits like Math.imul in the preview
    function rnd(i as Number, salt as Number) as Float {
        var x = i * 374761393 + salt * 668265263;
        x = x ^ ((x >> 13) & 0x7FFFF);
        x = x * 1274126177;
        x = x ^ ((x >> 16) & 0xFFFF);
        return (x & 0xFFFF) / 65535.0;
    }

    // [x, y] on the dial for an angle in Dc degrees (counter-clockwise from 3 o'clock)
    function ringPoint(angle as Numeric, r as Numeric) as Array<Float> {
        var a = angle * Math.PI / 180.0;
        return [227 + r * Math.cos(a), 227 - r * Math.sin(a)] as Array<Float>;
    }

    // flat [x0,y0,x1,y1,...] -> polygon, optionally shifted
    function pts(flat as Array<Number>, dx as Numeric, dy as Numeric) as Array {
        var n = flat.size() / 2;
        var out = new [n] as Array<Array<Numeric> >;
        for (var i = 0; i < n; i++) {
            out[i] = [flat[2 * i] + dx, flat[2 * i + 1] + dy] as Array<Numeric>;
        }
        return out;
    }

    // mirror a polygon around the waterline h and squash it by k
    function mirror(flat as Array<Number>, dy as Numeric, h as Numeric, k as Float) as Array {
        var n = flat.size() / 2;
        var out = new [n] as Array<Array<Numeric> >;
        for (var i = 0; i < n; i++) {
            out[i] = [flat[2 * i], h + (h - flat[2 * i + 1] - dy) * k] as Array<Numeric>;
        }
        return out;
    }

    function pad2(n as Number) as String { return n.format("%02d"); }

    function hm(sec as Number) as String { return pad2(sec / 3600) + ":" + pad2((sec / 60) % 60); }

    function thousands(n as Number or Null) as String {
        if (n == null) { return "--"; }
        if (n >= 1000) { return (n / 1000).toString() + "," + (n % 1000).format("%03d"); }
        return n.toString();
    }
}
