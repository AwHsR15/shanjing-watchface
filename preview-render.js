// 山境 v2 — browser mirror of the native renderer.
// Written against a small Dc shim that copies the Toybox.Graphics.Dc calls the watch uses,
// so source/*.mc and this file can be compared function by function.
'use strict';

// ------------------------------------------------------------------ Dc shim
const CW = true, CCW = false; // Graphics.ARC_CLOCKWISE / ARC_COUNTER_CLOCKWISE
class Dc {
  constructor(ctx, fonts) { this.c = ctx; this.fonts = fonts; this.fill = '#fff'; this.stroke = '#fff'; this.pen = 1; this.fg = 0xffffff; }
  static css(argb) { return `rgba(${(argb >> 16) & 255},${(argb >> 8) & 255},${argb & 255},${((argb >>> 24) & 255) / 255})`; }
  setFill(argb) { this.fill = Dc.css(argb); }
  setStroke(argb) { this.stroke = Dc.css(argb); }
  setColor(fg) { this.fg = fg; }
  setPenWidth(w) { this.pen = w; }
  setClip(x, y, w, h) { this.c.save(); this.c.beginPath(); this.c.rect(x, y, w, h); this.c.clip(); }
  clearClip() { this.c.restore(); }
  clear() { this.c.fillStyle = '#000'; this.c.fillRect(0, 0, 454, 454); }
  fillRectangle(x, y, w, h) { this.c.fillStyle = this.fill; this.c.fillRect(x, y, w, h); }
  fillCircle(x, y, r) { this.c.fillStyle = this.fill; this.c.beginPath(); this.c.arc(x, y, r, 0, 7); this.c.fill(); }
  fillEllipse(x, y, a, b) { this.c.fillStyle = this.fill; this.c.beginPath(); this.c.ellipse(x, y, a, b, 0, 0, 7); this.c.fill(); }
  fillPolygon(pts) { const c = this.c; c.fillStyle = this.fill; c.beginPath(); pts.forEach((p, i) => i ? c.lineTo(p[0], p[1]) : c.moveTo(p[0], p[1])); c.closePath(); c.fill(); }
  fillRoundedRectangle(x, y, w, h, r) { const c = this.c; c.fillStyle = this.fill; c.beginPath(); c.roundRect(x, y, w, h, r); c.fill(); }
  drawRoundedRectangle(x, y, w, h, r) { const c = this.c; c.strokeStyle = this.stroke; c.lineWidth = this.pen; c.beginPath(); c.roundRect(x + .5, y + .5, w - 1, h - 1, r); c.stroke(); }
  drawCircle(x, y, r) { const c = this.c; c.strokeStyle = this.stroke; c.lineWidth = this.pen; c.beginPath(); c.arc(x, y, r, 0, 7); c.stroke(); }
  drawLine(x1, y1, x2, y2) { const c = this.c; c.strokeStyle = this.stroke; c.lineWidth = this.pen; c.lineCap = 'round'; c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2); c.stroke(); }
  // degrees counter-clockwise from 3 o'clock, like Dc.drawArc
  drawArc(x, y, r, clockwise, a0, a1) { const c = this.c; c.strokeStyle = this.stroke; c.lineWidth = this.pen; c.lineCap = 'butt'; c.beginPath(); c.arc(x, y, r, -a0 * Math.PI / 180, -a1 * Math.PI / 180, !clockwise); c.stroke(); }
  textWidth(text, font) { const g = this.fonts[font].glyphs; let w = 0; for (const ch of String(text)) w += g[ch] ? g[ch][6] : 0; return w; }
  glyph(font, ch, x, y) { const f = this.fonts[font], g = f.glyphs[ch]; if (g && g[2]) this.c.drawImage(this.fonts.tinted(font, this.fg), g[0], g[1], g[2], g[3], x + g[4], y + g[5], g[2], g[3]); return g ? g[6] : 0; }
  // y is the top of the line; just: 0 right, 1 centre, 2 left (Graphics.TEXT_JUSTIFY_*)
  drawText(x, y, font, text, just) {
    text = String(text); const w = this.textWidth(text, font);
    let pen = just === 1 ? x - Math.floor(w / 2) : just === 0 ? x - w : x;
    for (const ch of text) pen += this.glyph(font, ch, pen, y);
  }
  // text along a circle; angle = centre of the text, degrees CCW from 3 o'clock.
  // radius is the circle through the middle of the glyphs. Top text reads clockwise, bottom text counter-clockwise.
  drawRadialText(x, y, font, text, angle, radius, clockwise) {
    text = String(text); const f = this.fonts[font], c = this.c, w = this.textWidth(text, font);
    const mid = f.base - f.cap / 2, span = w / radius;
    let a = angle * Math.PI / 180 + (clockwise ? span / 2 : -span / 2);
    for (const ch of text) {
      const g = f.glyphs[ch]; if (!g) continue; const adv = g[6] / radius;
      const ac = clockwise ? a - adv / 2 : a + adv / 2;
      c.save(); c.translate(x + radius * Math.cos(ac), y - radius * Math.sin(ac));
      c.rotate(clockwise ? Math.PI / 2 - ac : -Math.PI / 2 - ac);
      if (g[2]) c.drawImage(this.fonts.tinted(font, this.fg), g[0], g[1], g[2], g[3], -g[6] / 2 + g[4], -mid + g[5], g[2], g[3]);
      c.restore(); a = clockwise ? a - adv : a + adv;
    }
  }
}

// ------------------------------------------------------------------ helpers (Util.mc)
function argb(a, rgb) { return ((a & 255) << 24 | (rgb & 0xffffff)) >>> 0; }
function mix(a, b, t) {
  if (t <= 0) return a; if (t >= 1) return b;
  const r = ((a >> 16) & 255) + (((b >> 16) & 255) - ((a >> 16) & 255)) * t;
  const g = ((a >> 8) & 255) + (((b >> 8) & 255) - ((a >> 8) & 255)) * t;
  const bl = (a & 255) + ((b & 255) - (a & 255)) * t;
  return (Math.round(r) << 16) | (Math.round(g) << 8) | Math.round(bl);
}
function shade(c, k) { return mix(0, c, k); }
function grey(c) { const l = Math.round(((c >> 16) & 255) * .3 + ((c >> 8) & 255) * .59 + (c & 255) * .11); return mix((l << 16) | (l << 8) | l, 0x8090a0, .25); }
function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
function ease(t) { t = clamp(t, 0, 1); return 1 - (1 - t) * (1 - t) * (1 - t); }
// deterministic pseudo random in [0,1], identical to Util.rnd in Monkey C
function rnd(i, salt) { let x = (Math.imul(i, 374761393) + Math.imul(salt, 668265263)) | 0; x ^= (x >> 13) & 0x7ffff; x = Math.imul(x, 1274126177); x ^= (x >> 16) & 0xffff; return (x & 0xffff) / 65535; }
function poly(dc, pts, dx, dy) { dc.fillPolygon(pts.map(q => [q[0] + dx, q[1] + dy])); }
function polyMirror(dc, pts, dy, h, k) { dc.fillPolygon(pts.map(q => [q[0], h + (h - q[1] - dy) * k])); }
function ringPoint(angle, r) { const a = angle * Math.PI / 180; return [227 + r * Math.cos(a), 227 - r * Math.sin(a)]; }

// ------------------------------------------------------------------ palette (Palette.mc)
// Keyframes by approximate sun altitude (degrees). Colours per key:
const P_ZEN = 0, P_MID = 1, P_HOR = 2, P_FAR = 3, P_ROCKL = 4, P_ROCKS = 5, P_SNOWL = 6, P_SNOWS = 7, P_RIDGE = 8, P_NEAR = 9, P_WATER = 10, P_SUN = 11, P_GLOW = 12;
const KEY_ALT = [-14, -6, -1.5, 3, 10, 26];
const KEYS = [
  // zenith   sky-mid   horizon   far       rock-lit  rock-shd  snow-lit  snow-shd  ridge     near      water     sun       glow
  [0x050a17, 0x0b1730, 0x1b2c4a, 0x1d2c49, 0x18253d, 0x111b2f, 0x9fb2cf, 0x4b5c7c, 0x0e1727, 0x060b15, 0x0a1426, 0xeef2f8, 0x8fa8d8],
  [0x0c1836, 0x26376a, 0x5a6294, 0x3c4573, 0x2d375a, 0x212a49, 0xb4bae0, 0x6670a0, 0x1b2242, 0x0b1021, 0x1a2242, 0xffd2b0, 0xc8a8c8],
  [0x1a2c5a, 0x4f5188, 0xe5937c, 0x6a6490, 0x5a4b6c, 0x3a395f, 0xf7c0ac, 0x8c84ad, 0x2b2947, 0x121229, 0x3a3456, 0xffb27a, 0xffa070],
  [0x274474, 0x6d76a2, 0xf2b06c, 0x8a829e, 0x8a5f50, 0x4a4666, 0xffcf8a, 0x9a8fb2, 0x38334e, 0x181627, 0x4c4560, 0xffd59a, 0xffb060],
  [0x24548c, 0x5a88b8, 0xd9d6c4, 0x8797b2, 0x6c6a74, 0x4a5472, 0xfff3e0, 0xa0adca, 0x33405a, 0x152030, 0x3c5270, 0xfff4d8, 0xffe0a0],
  [0x184f8c, 0x3e7cb4, 0xa9cce0, 0x86a6c2, 0x5d6d80, 0x42536d, 0xfafcff, 0xa6bcd6, 0x2c4357, 0x13212f, 0x2e4b65, 0xfffbe8, 0xfff0c0],
];
// evening keys are warmer than morning ones (horizon, snow and glow only)
const EVENING = { 2: [[P_HOR, 0xd9706e], [P_SNOWL, 0xf2a59a], [P_GLOW, 0xff7f6a]], 3: [[P_HOR, 0xf0965a], [P_SNOWL, 0xffbe78], [P_GLOW, 0xff9a50]] };
function keyColor(k, i, evening) { if (evening && EVENING[k]) for (const [j, c] of EVENING[k]) if (j === i) return c; return KEYS[k][i]; }
function palette(alt, evening, overcast, wet) {
  let k = 0, t = 0;
  if (alt >= KEY_ALT[KEY_ALT.length - 1]) { k = KEY_ALT.length - 2; t = 1; }
  else if (alt > KEY_ALT[0]) { while (alt > KEY_ALT[k + 1]) k++; t = (alt - KEY_ALT[k]) / (KEY_ALT[k + 1] - KEY_ALT[k]); }
  const p = [];
  for (let i = 0; i < 13; i++) {
    let c = mix(keyColor(k, i, evening), keyColor(k + 1, i, evening), t);
    if (overcast > 0 && i !== P_SUN && i !== P_GLOW) c = mix(c, grey(c), overcast * .8);
    if (wet && i <= P_HOR) c = shade(c, .82);
    p.push(c);
  }
  return p;
}

// ------------------------------------------------------------------ sun & moon
function sunState(now, rise, set) { // [altitude-ish degrees, evening?]
  if (now >= rise && now <= set) return [52 * Math.sin(Math.PI * (now - rise) / (set - rise)), now > (rise + set) / 2];
  const m = (now > set ? now - set : rise - now) / 60; return [-m * .22, now > set];
}
function moonPhase(y, m, d) { // 0 new .. .5 full .. 1 new
  const jd = Date.UTC(y, m - 1, d, 12) / 86400000 + 2440587.5;
  let p = ((jd - 2451550.26) / 29.530588853) % 1; return p < 0 ? p + 1 : p;
}

// ------------------------------------------------------------------ layout (Lay in Scene.mc)
// Upper ~47%: the landscape, sky filling the dial and darkening towards the rim; the sun path rides the top of the ring.
// Lower half (after 望山-X / v1): weather | big time | clock mode + seconds, the date with its 七曜 seal,
// one row of readings, and two gauges climbing the ring from the bottom with the watch battery between them.
const L = {
  ringR: 218, labelR: 198, timeX: 227, timeBase: 302,
  sideX: 72, sideRX: 384, dateY: 314, infoY: 354, batteryY: 404,
  steps: [264, 204], body: [276, 336], sunSpan: [177, 3], intro: 1.4,
};
const TRACK = 0x232a33;
const ACCENTS = [0xe5a54b, 0x5fc8d8, 0xf08aa0, 0xe8ecf2];      // 琥珀 青 樱 雪
const WEEK_COLORS = [0xf2a65a, 0xc9d3e0, 0xf07a62, 0x6fb6e8, 0x7cc48a, 0xf0c75e, 0xc49a6c]; // 日 月 火 水 木 金 土

// ------------------------------------------------------------------ calendar-driven scene choice (Scene.prepare)
// 0 spring 1 summer 2 autumn 3 winter
function seasonOf(month) { return month >= 3 && month <= 5 ? 0 : month <= 8 && month >= 6 ? 1 : month >= 9 && month <= 11 ? 2 : 3; }
// seasons recolour the near land: [hills, ground, trees, amount]
const SEASON_LAND = [[0x3d6a48, 0x1f3a26, 0x1a3020, .32], [0x2c5a38, 0x163020, 0x10261a, .38], [0x8a5a30, 0x3a2414, 0x4a2412, .34], [0xc8d4e0, 0xdfe7ef, 0x2a3440, .5]];

// ------------------------------------------------------------------ event days (Events.mc)
// One event per day. Priority: lunar festivals > 除夕 > term days (清明, 节分) > fixed dates > Easter > seasons.
//  1 春节  2 元宵  3 中秋/月见  4 圣诞  5 万圣  6 除夕  7 正月/元旦  8 情人节  9 儿童节  10 端午  11 七夕(农历)
// 12 重阳  13 跨年  14 清明  15 节分  16 女儿节  17 赏樱  18 男孩节  19 七夕(公历)  20 盂兰盆  21 红叶  22 复活节
const FESTIVAL_NAMES = [null, '春节', '元宵', '中秋', '圣诞', '万圣', '除夕', '正月', '情人节', '儿童节', '端午', '七夕',
  '重阳', '跨年', '清明', '节分', '女儿节', '赏樱', '男孩节', '七夕', '盂兰盆', '红叶', '复活节'];
// each event leans the sky towards its own hue: [zenith, mid, horizon, amount]
const FESTIVAL_SKY = [null, [0x4a0f14, 0x8c2a22, 0xf0a050, .55], [0x2a0f2a, 0x6a2a3a, 0xf09a50, .45], [0x0c1430, 0x23305e, 0xd8a85a, .45],
  [0x07241c, 0x14523c, 0x9fd0a8, .5], [0x1c0c2a, 0x5a2a4a, 0xf08a3a, .55], [0x4a0f14, 0x8c2a22, 0xf0a050, .55],
  [0x0c1838, 0x2a3a78, 0xe8c070, .4], [0x3a1430, 0x8a3a6a, 0xf4a0b8, .5], [0x1a3a6a, 0x4a8ad0, 0xf8d080, .35],
  [0x0c2a2a, 0x2a6a5a, 0xc8e0a0, .4], [0x140c30, 0x3a2a6a, 0xd890c0, .5], [0x2a1a0c, 0x7a5a2a, 0xf0c060, .4],
  [0x0c1030, 0x2a2a68, 0xe8b860, .4], [0x1a2a2a, 0x5a7a72, 0xc0d8c8, .35], [0x2a1a10, 0x6a4a3a, 0xe8c090, .3],
  [0x3a1a30, 0x9a5a7a, 0xf8c0d0, .45], [0x2a2a4a, 0x8a7aa8, 0xf8d0e0, .35], [0x1a4a7a, 0x5a9ad0, 0xd8f0f8, .3],
  [0x140c30, 0x3a2a6a, 0xd890c0, .45], [0x1a0c20, 0x4a2a4a, 0xe89a60, .35], [0x2a140c, 0x7a3a24, 0xf0905a, .3],
  [0x2a3a5a, 0x7aa0d0, 0xf0e0a0, .3]];
// events whose sky already has a centrepiece: no extra goal fireworks there
const SKY_CENTREPIECE = [3, 5, 11, 14];
function nextDay(y, m, d) {
  const len = [31, (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0 ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1];
  return d < len ? [y, m, d + 1] : m < 12 ? [y, m + 1, 1] : [y + 1, 1, 1];
}
function easter(y) { // anonymous Gregorian computus -> [month, day]
  const a = y % 19, b = Math.floor(y / 100), c = y % 100, d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30, i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451);
  return [Math.floor((h + l - 7 * m + 114) / 31), (h + l - 7 * m + 114) % 31 + 1];
}
function festivalOf(s) {
  if (s.festival != null) return s.festival;
  const { year: y, month: m, day: d } = s, l = Cal.lunar(y, m, d), md = m * 100 + d;
  if (l && !l[2]) {
    const [lm, ld] = l;
    if (lm === 1 && ld <= 7) return 1;
    if (lm === 1 && ld === 15) return 2;
    if (lm === 5 && ld === 5) return 10;
    if (lm === 7 && ld === 7) return 11;
    if (lm === 8 && ld === 15) return 3;
    if (lm === 9 && ld === 9) return 12;
  }
  const next = nextDay(y, m, d), n = Cal.lunar(...next);
  if (n && n[0] === 1 && n[1] === 1 && !n[2]) return 6;
  if (Cal.term(y, m, d) === '清明') return 14;
  if (Cal.term(...next) === '立春') return 15;
  if (md >= 101 && md <= 103) return 7;
  if (md === 214) return 8;
  if (md === 303) return 16;
  if (md === 505) return 18;
  if (md === 601) return 9;
  if (md === 707) return 19;
  if (md >= 813 && md <= 816) return 20;
  if (md === 1031) return 5;
  if (md === 1224 || md === 1225) return 4;
  if (md === 1231) return 13;
  const [em, ed] = easter(y); if (m === em && d === ed) return 22;
  if (md >= 325 && md <= 410) return 17;
  if (md >= 1110 && md <= 1125) return 21;
  return 0;
}
function festivalPalette(p, fest) {
  const k = FESTIVAL_SKY[fest]; if (!k) return;
  p[P_ZEN] = mix(p[P_ZEN], k[0], k[3]); p[P_MID] = mix(p[P_MID], k[1], k[3]); p[P_HOR] = mix(p[P_HOR], k[2], k[3]);
}
function star5(dc, x, y, r, c) { const st = []; for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * .44 : r; st.push([x + rr * Math.cos(a), y + rr * Math.sin(a)]); } dc.setFill(argb(255, c)); dc.fillPolygon(st); }
function summitFlag(dc, c) { const [x, y] = Geo.apex; dc.setStroke(argb(255, 0x3a3440)); dc.setPenWidth(1.5); dc.drawLine(x, y, x, y - 15); dc.setFill(argb(255, c)); dc.fillPolygon([[x + .5, y - 15], [x + 12, y - 11], [x + .5, y - 7]]); }
// sky centrepieces (static). Positions are fixed slots so nothing lands on the low-battery bolt at (349, 83)
function drawFestivalSky(dc, sc) {
  const fest = sc.fest, night = !sc.day;
  if (fest === 1 || fest === 6) { // 春节 / 除夕: two red lanterns, leaving the middle and both sides free for fireworks
    for (const [x, len] of [[170, 30], [284, 24]]) {
      dc.setStroke(argb(200, 0x3a1010)); dc.setPenWidth(1); dc.drawLine(x, 16, x, 16 + len);
      drawGlow(dc, x, 28 + len, 9, 0xff5a3a, .7);
      dc.setFill(argb(255, 0xd8282a)); dc.fillEllipse(x, 28 + len, 11, 9);
      dc.setFill(argb(255, 0xf2c255)); dc.fillRectangle(x - 5, 18 + len, 10, 3); dc.fillRectangle(x - 5, 36 + len, 10, 3);
      dc.setStroke(argb(255, 0xf2c255)); dc.drawLine(x, 39 + len, x, 46 + len);
    }
  }
  if (fest === 3) { // 中秋 / 月见: a large golden moon right of the peak, or left of it when the volcano is out
    const mx = sc.stress ? 156 : 290, my = sc.stress ? 96 : 100;
    drawGlow(dc, mx, my, 20, 0xffd890, .9);
    dc.setFill(argb(255, 0xfbe6b0)); dc.fillCircle(mx, my, 20);
    dc.setFill(argb(40, 0xc89a50)); dc.fillCircle(mx - 7, my - 6, 5); dc.fillCircle(mx + 6, my + 7, 4); dc.fillCircle(mx + 4, my - 8, 3);
  }
  if (fest === 4 && !sc.stress) { drawGlow(dc, Geo.apex[0], Geo.apex[1] - 12, 6, 0xffe08a, .9); star5(dc, Geo.apex[0], Geo.apex[1] - 12, 8, 0xffd75a); }
  if (fest === 5) { drawGlow(dc, 128, 92, 18, 0xff9a40, .9); dc.setFill(argb(255, 0xf6a24a)); dc.fillCircle(128, 92, 18); }
  if (fest === 11) { // 七夕: 牛郎 and 织女 either side of the Milky Way, magpies bridging it
    for (const [x, y, c] of [[150, 78, 0xfff0d0], [304, 46, 0xd8e8ff]]) { drawGlow(dc, x, y, 3, c, night ? 1 : .5); dc.setFill(argb(255, c)); dc.fillCircle(x, y, 2.2); }
    dc.setStroke(argb(night ? 200 : 150, night ? 0xc8d0e8 : 0x2a2440)); dc.setPenWidth(1.3);
    for (let i = 0; i < 9; i++) { const k = (i + 1) / 10, x = 150 + 154 * k, y = 78 - 32 * k - Math.sin(Math.PI * k) * 26; dc.drawLine(x - 4, y - 2, x, y); dc.drawLine(x, y, x + 4, y - 2); }
  }
  if (fest === 12 && !sc.stress) summitFlag(dc, 0xf0b030);
  if (fest === 14) { // 清明: willow strands hanging from a branch that follows the inside of the sun ring
    const tops = [[96, 76], [110, 65], [124, 56], [138, 48], [152, 42], [166, 37]];
    dc.setStroke(argb(190, 0x4a5a2a)); dc.setPenWidth(1.6);
    for (let i = 0; i < 5; i++) dc.drawLine(tops[i][0], tops[i][1], tops[i + 1][0], tops[i + 1][1]);
    dc.setPenWidth(1.2);
    for (let i = 0; i < 6; i++) {
      const [x0, y0] = tops[i], len = 36 + (i % 3) * 14;
      dc.setStroke(argb(170, 0x6a8a3a)); dc.drawLine(x0, y0, x0 + 5, y0 + len);
      dc.setFill(argb(200, 0x9ac060)); for (let j = 1; j < 5; j++) dc.fillEllipse(x0 + 5 * j / 5, y0 + len * j / 5, 1.6, 3);
    }
  }
}
// scattered dots on the hills: blossom, chrysanthemums, autumn colour (static)
function speckles(dc, n, salt, cols, alpha, r) {
  for (let i = 0; i < n; i++) {
    const x = 20 + rnd(i, salt) * 414, top = Geo.skyline[clamp(Math.round(x / 2), 0, Geo.skyline.length - 1)];
    const y = Math.max(top + 4, 176 + rnd(i, salt + 1) * 30);
    if (y > Geo.horizon - 2) continue;
    dc.setFill(argb(alpha, cols[i % cols.length])); dc.fillCircle(x, y, r + rnd(i, salt + 2));
  }
}
// land decorations that belong to the day (static)
function drawFestivalLand(dc, sc) {
  const fest = sc.fest;
  if (fest === 12) speckles(dc, 26, 101, [0xf6c43a, 0xf6c43a, 0xffe07a], 220, 1.6);
  if (fest === 17) speckles(dc, 40, 141, [0xf8c0d0, 0xffe0ea, 0xf0a0b8], 220, 1.4);
  if (fest === 21) speckles(dc, 40, 151, [0xd8402a, 0xe86a2a, 0xb02a1a], 200, 1.5);
  if (fest === 16) { // 女儿节: peach blossom on the near pines
    for (const [role, pts] of Geo.shapes) if (role === 'tree') for (let k = 0; k < 3; k++) { const [x, y] = pts[0]; dc.setFill(argb(230, k % 2 ? 0xf8a0b8 : 0xffd0dc)); dc.fillCircle(x + (k - 1) * 3, y + 5 + k * 4, 1.6); }
  }
  if (fest === 22) { // 复活节: painted eggs hidden on the hills
    const cols = [0xf8a0b8, 0x8ad0f0, 0xf8d870, 0xa8e090, 0xc8a0f0];
    for (let i = 0; i < 7; i++) {
      const x = 40 + rnd(i, 161) * 370, y = Math.max(Geo.skyline[clamp(Math.round(x / 2), 0, Geo.skyline.length - 1)] + 6, 190 + rnd(i, 162) * 14);
      if (y > Geo.horizon - 3) continue;
      dc.setFill(argb(255, cols[i % 5])); dc.fillEllipse(x, y, 2.6, 3.4); dc.setFill(argb(200, 0xffffff)); dc.fillRectangle(x - 2.6, y - .5, 5.2, 1);
    }
  }
  if (fest === 20) { // 盂兰盆: a string of paper lanterns between the right-hand pines
    dc.setStroke(argb(160, 0x2a2018)); dc.setPenWidth(1); dc.drawLine(356, 162, 420, 166);
    for (let i = 0; i < 5; i++) {
      const x = 362 + i * 13, y = 168 + Math.sin(i * 1.3) * 1.5;
      if (!sc.day) drawGlow(dc, x, y, 3, 0xffa050, .6);
      dc.setFill(argb(255, i % 2 ? 0xf4ead8 : 0xe8503a)); dc.fillEllipse(x, y, 3.2, 4.2);
    }
  }
}
// decorations at the cabin (static)
function drawFestivalCabin(dc, sc) {
  const fest = sc.fest;
  if (fest === 4) { const cols = [0xff5a5a, 0x7ae08a, 0xffd36a, 0x6ab8ff]; for (let i = 0; i < 7; i++) { dc.setFill(argb(255, cols[i % 4])); dc.fillCircle(314 + i * 4, 190 + Math.abs(i - 3) * 2.6, 1.3); } }
  if (fest === 5) { drawGlow(dc, 312, 200, 4, 0xff8a2a, .8); dc.setFill(argb(255, 0xf08a2a)); dc.fillEllipse(312, 200, 4, 3); }
  if (fest === 1 || fest === 6) { dc.setFill(argb(255, 0xd8282a)); dc.fillRectangle(318.5, 193, 1.8, 7); dc.fillRectangle(326, 193, 1.8, 7); dc.fillRectangle(320, 190.5, 6, 1.8); }
  if (fest === 10) { dc.setStroke(argb(255, 0x5a9a3a)); dc.setPenWidth(1.4); dc.drawLine(321, 192, 317, 202); dc.drawLine(325, 192, 329, 202); dc.setFill(argb(255, 0xe04a4a)); dc.fillPolygon([[332, 196], [334, 198.5], [332, 201], [330, 198.5]]); }
  if (fest === 7) { // 正月: kadomatsu beside the door
    dc.setFill(argb(255, 0x6a4a2a)); dc.fillRectangle(305, 196, 10, 5);
    dc.setFill(argb(255, 0x4aa058));
    for (const [x, h] of [[307, 11], [310, 14], [313, 10]]) dc.fillPolygon([[x - 1.2, 196], [x - 1.2, 196 - h + 2], [x + 1.2, 196 - h], [x + 1.2, 196]]);
    dc.setFill(argb(255, 0x2a6a3a)); dc.fillEllipse(310, 195, 6, 2.5);
  }
  if (fest === 15) { dc.setStroke(argb(255, 0x3a7a3a)); dc.setPenWidth(1.4); dc.drawLine(323, 190, 323, 184); dc.setFill(argb(255, 0x3a7a3a)); dc.fillEllipse(321, 184, 2, 1.4); dc.fillEllipse(325, 185, 2, 1.4); dc.setFill(argb(255, 0xa8b0b8)); dc.fillEllipse(323, 187, 1.2, 2.5); }
  if (fest === 19) { // 七夕 (公历): a bamboo branch with paper wishes, leaning left, away from the chimney smoke
    dc.setStroke(argb(255, 0x4a8a3a)); dc.setPenWidth(1.6); dc.drawLine(312, 202, 302, 166);
    const cols = [0xf05a5a, 0xf8d050, 0x5ab0f0, 0x8ad070, 0xd08af0];
    for (let i = 0; i < 5; i++) { const x = 311 - i * 2.2, y = 196 - i * 7; dc.setStroke(argb(255, 0x5aa04a)); dc.setPenWidth(1); dc.drawLine(x, y, x - 6, y - 2); dc.setFill(argb(255, cols[i])); dc.fillRectangle(x - 6, y - 1, 2, 5); }
  }
}
// ------------------------------------------------------------------ event-day motion
// burst centres in order of preference; any slot near the bolt, the erupting summit or an earlier burst is skipped
const FIREWORK_SLOTS = [[120, 66], [330, 58], [205, 38], [296, 50], [168, 52]], NEW_YEAR_SLOTS = [[100, 80], [354, 74], [227, 40]];
function fireworkSlots(sc) {
  const keep = [], busy = [];
  if (sc.lowBattery) busy.push([349, 83]);
  if (sc.stress) busy.push([244, 58]);
  for (const [x, y] of sc.fest === 1 || sc.fest === 6 ? NEW_YEAR_SLOTS : FIREWORK_SLOTS) {
    if (keep.length < 3 && busy.every(([bx, by]) => (x - bx) ** 2 + (y - by) ** 2 >= 46 * 46) && keep.every(([kx, ky]) => (x - kx) ** 2 + (y - ky) ** 2 >= 56 * 56)) keep.push([x, y]);
  }
  return keep;
}
function wantsFireworks(sc) { return !sc.day && ([1, 6, 7, 13].includes(sc.fest) || (sc.goal && !SKY_CENTREPIECE.includes(sc.fest))); }
function drawHearts(dc, s, t) { // 情人节: hearts drifting up
  for (let i = 0; i < 7; i++) {
    const ph = ((s.motion === 0 ? t * .07 : .4) + rnd(i, 111)) % 1, x = 70 + rnd(i, 112) * 314 + Math.sin(ph * 7 + i) * 8, y = 205 - ph * 180, r = 3 + rnd(i, 113) * 2.5;
    dc.setFill(argb(Math.round(220 * Math.min(1, (1 - ph) * 3)), i % 2 ? 0xff7aa0 : 0xffb0c8));
    dc.fillCircle(x - r * .5, y - r * .2, r * .62); dc.fillCircle(x + r * .5, y - r * .2, r * .62); dc.fillPolygon([[x - r * 1.1, y], [x + r * 1.1, y], [x, y + r * 1.2]]);
  }
}
function drawBalloons(dc, s, t) { // 儿童节: balloons rising from the meadow
  const cols = [0xff6a6a, 0xffcf4a, 0x6ac8ff, 0x8ae07a, 0xd08aff];
  for (let i = 0; i < 6; i++) {
    const ph = ((s.motion === 0 ? t * .05 : .45) + rnd(i, 121)) % 1, x = 70 + rnd(i, 122) * 314 + Math.sin(ph * 6 + i) * 6, y = 210 - ph * 190;
    dc.setStroke(argb(160, 0xd8d8d8)); dc.setPenWidth(1); dc.drawLine(x, y + 7, x + Math.sin(t * 2 + i) * 2, y + 20);
    dc.setFill(argb(240, cols[i % 5])); dc.fillEllipse(x, y, 5.5, 7);
    dc.setFill(argb(120, 0xffffff)); dc.fillEllipse(x - 2, y - 3, 1.5, 2.2);
  }
}
// falling things: confetti, sakura petals, maple leaves
function drawFalling(dc, s, t, kind) {
  const cols = kind === 0 ? [0xffd36a, 0xff6a6a, 0x6ad8c8, 0xffffff] : kind === 1 ? [0xffc8d8, 0xffe4ec, 0xf8a8c0] : [0xd8402a, 0xe8702a, 0xc0301a, 0xf0a030];
  const n = kind === 0 ? 30 : 22, speed = kind === 0 ? 30 : kind === 1 ? 16 : 22;
  for (let i = 0; i < n; i++) {
    const y = ((rnd(i, 131) * 190 + (s.motion === 0 ? t * (speed + rnd(i, 132) * speed) : 0)) % 190) + 24, x = 50 + rnd(i, 133) * 354 + (s.motion === 0 ? Math.sin(t * 1.5 + i) * (kind === 0 ? 7 : 14) : 0);
    if ((x - 227) ** 2 + (y - 227) ** 2 > 190 * 190) continue;
    const spin = Math.abs(Math.sin((s.motion === 0 ? t * 4 : 0) + i));
    dc.setFill(argb(230, cols[i % cols.length]));
    if (kind === 0) dc.fillRectangle(x - (1 + 2.5 * spin) / 2, y, 1 + 2.5 * spin, 3);
    else if (kind === 1) dc.fillEllipse(x, y, 1 + 2 * spin, 2.2);
    else star5(dc, x, y, 2.5 + spin * 1.5, cols[i % cols.length]);
  }
}
function drawKite(dc, s, t) { // 清明: a kite on a long string, tied left of the cabin
  const x = 284 + (s.motion === 0 ? Math.sin(t * 1.1) * 6 : 0), y = 74 + (s.motion === 0 ? Math.cos(t * .9) * 3 : 0);
  dc.setStroke(argb(150, 0xe0e0e0)); dc.setPenWidth(1); dc.drawLine(x, y + 9, 300, 198);
  dc.setFill(argb(255, 0xe85a4a)); dc.fillPolygon([[x, y - 10], [x + 7, y], [x, y + 9], [x - 7, y]]);
  dc.setFill(argb(255, 0xffd06a)); dc.fillPolygon([[x, y - 10], [x + 7, y], [x, y]]);
  dc.setStroke(argb(200, 0xffd06a));
  for (let i = 0; i < 4; i++) { const tx = x - 2 - i * 5, ty = y + 12 + i * 6 + Math.sin(t * 3 + i) * 2; dc.drawLine(tx - 2, ty - 2, tx + 2, ty + 2); }
}
function drawBeans(dc, s, t) { // 节分: roasted beans tossed out of the cabin door
  for (let i = 0; i < 9; i++) {
    const ph = ((s.motion === 0 ? t * .8 : .5) + i / 9) % 1, vx = -40 - rnd(i, 171) * 60, vy = -70 - rnd(i, 172) * 40;
    const x = 323 + vx * ph, y = 194 + vy * ph + 120 * ph * ph;
    if (y > 202) continue;
    dc.setFill(argb(240, 0xe0c080)); dc.fillCircle(x, y, 1.6);
  }
}
function drawKoinobori(dc, s, t) { // 男孩节: carp streamers on a pole beside the cabin
  dc.setStroke(argb(255, 0xd8d0c0)); dc.setPenWidth(1.6); dc.drawLine(302, 202, 302, 128);
  const cols = [[0x2a2a38, 0xe8e8e8], [0xe0402a, 0xf8d0c0], [0x2a7ad8, 0xd0e8f8]];
  for (let k = 0; k < 3; k++) {
    const y0 = 134 + k * 11, len = 26 - k * 3, top = [], bot = [];
    for (let i = 0; i <= 8; i++) {
      const u = i / 8, x = 304 + u * len, w = (s.motion === 0 ? Math.sin(t * 5 - u * 5 + k) : .3) * 2.5 * u, h = 4.5 * (1 - u * .35);
      top.push([x, y0 - h + w]); bot.push([x, y0 + h + w]);
    }
    dc.setFill(argb(255, cols[k][0])); dc.fillPolygon(top.concat(bot.reverse()));
    dc.setFill(argb(255, cols[k][1])); dc.fillCircle(308, y0 - 1, 1.6);
  }
}

// ------------------------------------------------------------------ sky
function skyColor(p, y) { // nonlinear so the bright horizon stays low, behind the mountains
  const h = Geo.horizon;
  if (y < 120) return mix(p[P_ZEN], p[P_MID], Math.pow(Math.max(0, y) / 120, 1.3));
  return mix(p[P_MID], p[P_HOR], Math.pow((y - 120) / (h - 120), 1.7));
}
const BAYER = [0, .5, .25, .75];
function dither565(c, y) { // ordered dither: nudge each row before the 16-bit panel drops the low bits
  const o5 = [0, 4, 2, 6][y & 3], o6 = [0, 2, 1, 3][y & 3];
  return (Math.min(255, ((c >> 16) & 255) + o5) & 0xf8) << 16 | (Math.min(255, ((c >> 8) & 255) + o6) & 0xfc) << 8 | (Math.min(255, (c & 255) + o5) & 0xf8);
}
function drawSky(dc, p) { for (let y = 0; y < Geo.horizon; y++) { dc.setFill(argb(255, dither565(skyColor(p, y), y))); dc.fillRectangle(0, y, 454, 1); } }
// moving things drawn over the cached layer may only use open sky
function skyOpen(x, y) {
  if ((x - 227) ** 2 + (y - 227) ** 2 > 186 * 186) return false;
  return y < Geo.skyline[clamp(Math.round(x / 2), 0, Geo.skyline.length - 1)] - 3;
}
function drawStars(dc, s, alpha, t, e) {
  if (alpha <= .02) return;
  for (let i = 0; i < 60; i++) {
    const x = 40 + rnd(i, 1) * 374, y = 26 + rnd(i, 2) * 150, b = rnd(i, 3);
    if (!skyOpen(x, y)) continue;
    const tw = s.motion === 0 ? .55 + .45 * Math.sin(t * (1.3 + b * 2.2) + i * 1.9) : 1;
    dc.setFill(argb(Math.round(255 * alpha * e * (b > .86 ? 1 : .35 + b * .5) * tw), b > .93 ? 0xfff2d6 : 0xdfe8ff));
    dc.fillCircle(x, y, b > .86 ? 1.6 : b > .5 ? 1.1 : .8);
  }
}
// the Milky Way: a faint diagonal band thick with dust-like stars (static, clear nights)
function drawMilkyWay(dc, alpha) {
  if (alpha <= .3) return;
  const band = (w, a) => { dc.setFill(argb(Math.round(a * alpha), 0xb8c4e8)); dc.fillPolygon([[40, 150 - w], [200, 60 - w], [420, 20 - w], [420, 20 + w], [200, 60 + w], [40, 150 + w]]); };
  band(26, 10); band(15, 12); band(6, 14);
  for (let i = 0; i < 90; i++) {
    const k = rnd(i, 61), x = 40 + k * 380, yc = k < .42 ? 150 - k / .42 * 90 : 60 - (k - .42) / .58 * 40, y = yc + (rnd(i, 62) - .5) * 38;
    if (!skyOpen(x, y)) continue;
    dc.setFill(argb(Math.round((60 + 90 * rnd(i, 63)) * alpha), 0xe6ecff)); dc.fillCircle(x, y, .7);
  }
}
// aurora on clear winter nights: three soft curtains (static)
function drawAurora(dc, alpha) {
  const colors = [0x5fe0a8, 0x48c8c0, 0x9a7ae0];
  for (let k = 0; k < 3; k++) {
    const top = [], bot = [];
    for (let i = 0; i <= 12; i++) { const x = 30 + i * 33, y = 70 + k * 18 + Math.sin(i * .7 + k * 1.3) * 16; top.push([x, y - 18 + k * 4]); bot.push([x, y + 26]); }
    for (let j = 0; j < 3; j++) { dc.setFill(argb(Math.round((16 + j * 8) * alpha), colors[k])); dc.fillPolygon(top.map(([x, y]) => [x, y + j * 7]).concat(bot.slice().reverse())); }
  }
}
function drawGlow(dc, x, y, r, color, strength) { // faint discs read as a soft halo
  for (let i = 6; i >= 1; i--) { dc.setFill(argb(Math.round(255 * strength * .045 * (1 + (6 - i) * .3)), color)); dc.fillCircle(x, y, r * (1 + i * .7)); }
}
function drawClouds(dc, p, amount, drift) { // soft wisps drifting across the sky; they fade near the rim so a cloud can wrap round unseen
  if (amount <= 0) return;
  const n = Math.round(2 + amount * 4), lit = mix(p[P_GLOW], 0xffffff, .5), dark = mix(p[P_RIDGE], p[P_MID], .4), a = 40 + amount * 50;
  for (let i = 0; i < n; i++) {
    const w = 60 + rnd(i, 11) * 70, y = 44 + rnd(i, 12) * 76, x = 60 + (40 + rnd(i, 13) * 254 + drift * (4 + rnd(i, 14) * 6)) % 334;
    const k = clamp((212 - Math.hypot(x - 227, y - 227) - w * .25) / 40, 0, 1);
    if (k <= 0) continue;
    dc.setFill(argb(a * .8 * k, dark)); dc.fillEllipse(x + w * .06, y + 5, w * .46, 4.5);
    dc.setFill(argb(a * k, lit)); dc.fillEllipse(x, y, w * .5, 4); dc.fillEllipse(x - w * .12, y - 3, w * .3, 4.5); dc.fillEllipse(x + w * .2, y + 1, w * .24, 3.5);
  }
}
function drawFog(dc, p, drift) { // fog banks swaying slowly across the valley
  const c = mix(p[P_HOR], 0xffffff, .35);
  for (let k = 0; k < 3; k++) {
    const x = 227 + Math.sin(drift * (.12 + k * .05) + k * 2.1) * 80, y = 150 + k * 22;
    dc.setFill(argb(34, c)); dc.fillEllipse(x, y, 110 - k * 12, 10);
    dc.setFill(argb(26, c)); dc.fillEllipse(x + 30, y - 4, 70, 7);
  }
}
function drawRainbow(dc, alpha) { // daytime goal reached: a bow behind the peak
  const colors = [0xe0766c, 0xeab85f, 0x8fbf8e, 0x74b6cf];
  dc.setPenWidth(4);
  colors.forEach((c, i) => { dc.setStroke(argb(Math.round(130 * alpha), c)); dc.drawArc(227, 220, 150 - i * 4, CW, 165, 15); });
}
// ------------------------------------------------------------------ landscape
function haze(dc, color, y0, y1, a0, a1) { // vertical alpha gradient in ten bands
  const step = Math.floor((y1 - y0 + 9) / 10);
  for (let y = y0; y < y1; y += step) { dc.setFill(argb(Math.round(a0 + (a1 - a0) * (y - y0 + step / 2) / (y1 - y0)), color)); dc.fillRectangle(0, y, 454, Math.min(step, y1 - y)); }
}
// palette colour per landscape role; the lit and shaded snow faces swap when the sun crosses noon, the near land follows the season
function roleColor(p, role, sunLeft, season) {
  const lit = p[P_SNOWL], shd = mix(p[P_SNOWS], p[P_ROCKS], .15), land = SEASON_LAND[season], light = shade(mix(p[P_SNOWL], 0xffffff, .3), .9);
  const tint = (c, i) => mix(c, i === 1 && season === 3 ? mix(land[1], p[P_SNOWS], .5) : shade(land[i], clamp(lum(c) * 2.4 + .25, .25, 1)), land[3]);
  switch (role) {
    case 'far': return mix(p[P_FAR], p[P_HOR], .18);
    case 'range': return mix(p[P_FAR], p[P_RIDGE], .55);
    case 'body': return mix(p[P_ROCKS], p[P_NEAR], .45);
    case 'snowL': return sunLeft ? lit : mix(lit, shd, .55);
    case 'snowR': return sunLeft ? shd : mix(shd, lit, .6);
    case 'streakL': return mix(sunLeft ? lit : shd, p[P_ROCKS], .2);
    case 'streakR': return mix(sunLeft ? shd : lit, p[P_ROCKS], .35);
    case 'hills': return tint(p[P_RIDGE], 0);
    case 'treeFar': return shade(tint(p[P_RIDGE], 0), .7);
    case 'ground': return tint(p[P_NEAR], 1);
    default: return tint(shade(p[P_NEAR], .55), 2);
  }
}
function lum(c) { return (((c >> 16) & 255) * .3 + ((c >> 8) & 255) * .59 + (c & 255) * .11) / 255; }
function drawLand(dc, s, sc) {
  const p = sc.p;
  for (const [role, pts] of Geo.shapes) {
    dc.setFill(argb(255, roleColor(p, role, sc.sunLeft, sc.season))); dc.fillPolygon(pts);
    if (role === 'range') haze(dc, p[P_HOR], 160, 202, 0, 70);
    if (role === 'streakR') drawRidgeLight(dc, p, sc.sunLeft);
    if (role === 'snowR' && sc.stress) { dc.setFill(argb(255, 0xe88355)); dc.fillPolygon(Geo.lava); }
    if (role === 'tree' && sc.season === 3) { const [x, y] = pts[0]; dc.setFill(argb(255, mix(p[P_SNOWS], 0xffffff, .3))); dc.fillPolygon([[x, y], [x - 3, y + 6], [x + 3, y + 6]]); }
  }
  drawSeasonDots(dc, sc.season);
  drawFestivalLand(dc, sc);
  drawCabin(dc, s, sc);
}
// spring blossom on the hills, autumn colour in the far pines (static)
function drawSeasonDots(dc, season) {
  if (season !== 0 && season !== 2) return;
  const cols = season === 0 ? [0xf6b8c8, 0xffd6e0] : [0xe0703a, 0xf0a040, 0xc84a2a];
  for (let i = 0; i < 22; i++) {
    const x = 20 + rnd(i, 91) * 414, top = Geo.skyline[clamp(Math.round(x / 2), 0, Geo.skyline.length - 1)];
    const y = Math.max(top + 4, 176 + rnd(i, 92) * 30);
    if (y > Geo.horizon - 2) continue;
    dc.setFill(argb(season === 0 ? 190 : 130, cols[i % cols.length])); dc.fillCircle(x, y, 1.2 + rnd(i, 93));
  }
}
// a thin highlight along the ridges that face the sun (static)
function drawRidgeLight(dc, p, sunLeft) {
  const r = Geo.ridge, segs = sunLeft ? [[0, 1], [2, 3]] : [[3, 4], [5, 6]];
  dc.setPenWidth(1.5); dc.setStroke(argb(150, mix(p[P_SNOWL], 0xffffff, .4)));
  for (const [a, b] of segs) dc.drawLine(r[a][0], r[a][1], r[b][0], r[b][1]);
}
function drawCabin(dc, s, sc) {
  const p = sc.p, house = shade(roleColor(p, 'tree', sc.sunLeft, sc.season), 1);
  dc.setFill(argb(255, house)); dc.fillPolygon(Geo.chimney); dc.fillPolygon(Geo.cabin);
  dc.setFill(argb(255, mix(house, 0, .4))); dc.fillPolygon(Geo.door);
  const lit = s.notifications > 0, evening = !sc.day;
  dc.setFill(argb(255, lit ? 0xffc66a : evening ? 0x8a6a3a : mix(house, p[P_RIDGE], .5))); dc.fillPolygon(Geo.window);
  if (lit) drawGlow(dc, 330, 197, 4, 0xffb44a, .8);
  drawFestivalCabin(dc, sc);
}
// the ground melts into the black half instead of stopping on a hard line
function drawGroundFade(dc, p, season) {
  const base = roleColor(p, 'ground', true, season);
  for (let y = Geo.horizon; y < Geo.horizon + 36; y++) { dc.setFill(argb(255, mix(base, 0, Math.pow((y - Geo.horizon) / 36, .6)))); dc.fillRectangle(0, y, 454, 1); }
}
// the sky darkens towards the rim of the dial, the same kind of gradient as the ground below
function drawRimShade(dc) {
  dc.setPenWidth(8);
  for (let r = 178; r < 228; r += 8) { dc.setStroke(argb(Math.round(230 * Math.pow((r - 174) / 54, 1.6)), 0)); dc.drawArc(227, 227, r + 4, CW, 90, 270); dc.drawArc(227, 227, r + 4, CW, 270, 90); }
}

// ------------------------------------------------------------------ moving parts
function drawRain(dc, s, t, heavy) {
  dc.setStroke(argb(heavy ? 140 : 110, 0xc8d8ea)); dc.setPenWidth(1.4);
  for (let i = 0; i < (heavy ? 44 : 30); i++) {
    const len = 10 + rnd(i, 22) * 12, y = ((rnd(i, 24) * 200 + (s.motion === 0 ? t * (260 + rnd(i, 23) * 120) : 0)) % 200) + 20, x = 60 + rnd(i, 21) * 360 - (y - 20) * .18;
    if (y < Geo.horizon - 8 && (x - 227) ** 2 + (y - 227) ** 2 < 190 * 190) dc.drawLine(x, y, x - len * .18, y + len);
  }
}
function drawSnow(dc, s, t) {
  for (let i = 0; i < 40; i++) {
    const y = ((rnd(i, 33) * 200 + (s.motion === 0 ? t * (18 + rnd(i, 31) * 22) : 0)) % 196) + 20, x = 50 + rnd(i, 34) * 354 + (s.motion === 0 ? Math.sin(t * .9 + i) * 6 : 0);
    if ((x - 227) ** 2 + (y - 227) ** 2 < 190 * 190 && y < Geo.horizon) { dc.setFill(argb(Math.round(150 + 100 * rnd(i, 35)), 0xf4f8ff)); dc.fillCircle(x, y, .9 + rnd(i, 32) * 1.6); }
  }
}
function drawStorm(dc, s, t) { // a brief flash and a forked bolt
  const on = s.motion === 0 && ((t > 1.1 && t < 1.25) || (t > 5.3 && t < 5.42));
  if (!on) return;
  dc.setFill(argb(55, 0xe8ecff)); dc.fillRectangle(0, 0, 454, Geo.horizon);
  const x0 = t < 3 ? 150 : 300, pts = [[x0, 40], [x0 - 8, 70], [x0 + 4, 74], [x0 - 10, 110], [x0 + 2, 114], [x0 - 6, 150]];
  dc.setStroke(argb(240, 0xf4f6ff)); dc.setPenWidth(2);
  for (let i = 0; i < pts.length - 1; i++) dc.drawLine(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]);
  dc.setPenWidth(1); dc.drawLine(pts[2][0], pts[2][1], pts[2][0] + 14, pts[2][1] + 22);
}
function drawMeteor(dc, t0, t) {
  const f = (t - t0) / .7; if (f < 0 || f > 1) return;
  const x = 130 + f * 130, y = 40 + f * 44;
  for (let i = 0; i < 8; i++) { dc.setStroke(argb(Math.round(220 * (1 - i / 8) * Math.sin(Math.PI * f)), 0xffffff)); dc.setPenWidth(2); dc.drawLine(x - i * 7, y - i * 2.4, x - (i + 1) * 7, y - (i + 1) * 2.4); }
}
function drawFireworks(dc, s, t, slots) { // night-time goal, new year and new year's eve; slots keep clear of the day's centrepiece
  const colors = [0xffd36a, 0xff7aa8, 0x8fd0ff];
  for (let k = 0; k < slots.length; k++) {
    const ph = ((s.motion === 0 ? t : 1.0) + k * .55) % 1.6 / 1.6;
    const [bx, by] = slots[k], r = 4 + ph * 22, a = Math.round(230 * (1 - ph));
    dc.setFill(argb(a, colors[k]));
    for (let i = 0; i < 12; i++) { const an = i * Math.PI / 6 + k; dc.fillCircle(bx + Math.cos(an) * r, by + Math.sin(an) * r + ph * ph * 6, 1.6); }
    dc.setFill(argb(Math.round(a * .35), colors[k])); dc.fillCircle(bx, by, r * .35);
  }
}
function drawVolcano(dc, s, t) { // stress above the threshold: sparks over the summit
  const [x0, y0] = Geo.apex;
  drawGlow(dc, x0 - 2, y0 + 6, 6, 0xff7a3a, .9);
  for (let i = 0; i < 8; i++) {
    const ph = ((s.motion === 0 ? t * .9 : .5) + rnd(i, 51)) % 1;
    dc.setFill(argb(Math.round(240 * (1 - ph)), 0xff9b45)); dc.fillCircle(x0 + (rnd(i, 52) - .5) * 30 * ph, y0 - 4 - ph * 30, 1.8 * (1 - ph) + .6);
  }
}
function drawBolt(dc, s, t) { // low battery or charging: lightning in the sky
  if (s.motion === 0 && (t % 2.2) > 1.4 && (t % 2.2) < 1.6) return;
  dc.setFill(argb(255, 0xf8cc68)); dc.fillPolygon(Geo.bolt);
  drawGlow(dc, 349, 83, 7, 0xf8cc68, .5);
}
function drawSmoke(dc, s, t) { // the cabin chimney on cold days and at night
  const [x0, y0] = Geo.smoke;
  for (let i = 0; i < 5; i++) {
    const ph = ((s.motion === 0 ? t * .35 : .3) + i / 5) % 1;
    dc.setFill(argb(Math.round(110 * (1 - ph)), 0xc8ccd4)); dc.fillCircle(x0 + ph * 14 + Math.sin(ph * 6 + i) * 2, y0 - ph * 34, 2 + ph * 5);
  }
}
function drawBirds(dc, s, t) { // a small flock in a loose V gliding across a fair-weather day
  const lx = 64 + t * 26, ly = 104 - t * 2 + Math.sin(t * .7) * 4;
  dc.setStroke(argb(200, 0x22303c)); dc.setPenWidth(1.4);
  for (let i = 0; i < 5; i++) {
    const row = Math.floor((i + 1) / 2), x = lx - row * 11, y = ly + (i % 2 ? -1 : 1) * row * 7 + Math.sin(t * 1.7 + i) * 1.5;
    if ((x - 227) ** 2 + (y - 227) ** 2 > 186 * 186) continue;
    const flap = Math.sin(t * 8 + i * 1.3) * 2.6;
    dc.drawLine(x - 5, y - 1 - flap, x, y + 1); dc.drawLine(x, y + 1, x + 5, y - 1 - flap);
  }
}
function drawBats(dc, s, t) { // 万圣: bats flitting across the sky
  dc.setFill(argb(255, 0x140a18));
  for (let i = 0; i < 4; i++) {
    const x = (t * (14 + i * 4) + i * 90) % 330 + 60, y = 60 + i * 14 + Math.sin(t * 2 + i) * 8, w = 6 + Math.sin(t * 12 + i) * 3;
    dc.fillPolygon([[x - 9, y - w * .4], [x - 4, y], [x - 2, y - 2], [x, y + 2], [x + 2, y - 2], [x + 4, y], [x + 9, y - w * .4], [x + 3, y + 3], [x, y + 5], [x - 3, y + 3]]);
  }
}
function drawSkyLanterns(dc, s, t) { // 元宵: paper lanterns drifting up
  for (let i = 0; i < 6; i++) {
    const ph = ((s.motion === 0 ? t * .06 : .4) + rnd(i, 71)) % 1, x = 80 + rnd(i, 72) * 300 + Math.sin(ph * 6 + i) * 6, y = 200 - ph * 170;
    if (!skyOpen(x, y) && y > 100) continue;
    const a = Math.round(230 * Math.min(1, (1 - ph) * 3)), fl = s.motion === 0 ? .8 + .2 * Math.sin(t * 9 + i * 3) : 1;
    drawGlow(dc, x, y, 3, 0xffa040, .6 * fl);
    dc.setFill(argb(a, 0xffb050)); dc.fillRoundedRectangle(x - 3, y - 4, 6, 8, 2);
  }
}

// ------------------------------------------------------------------ ring
function cap(dc, a, r) { const [x, y] = ringPoint(a, L.ringR); dc.fillCircle(x, y, r); }
// upper half: the day (or night) from horizon to horizon with the sun or moon riding it; a rainbow ring when the day's goal is met
function drawSkyRing(dc, sc, e, t) {
  const { p, f, day } = sc, alpha = 1 - sc.overcast * .6, [a0, a1] = L.sunSpan, pos = a0 - (a0 - a1) * clamp(f, 0, 1) * e;
  if (sc.goal && day) { [0xe0766c, 0xeab85f, 0x8fbf8e, 0x74b6cf].forEach((c, i) => { dc.setPenWidth(2); dc.setStroke(argb(200, c)); dc.drawArc(227, 227, L.ringR + 4 - i * 2.5, CW, a0, a1); }); }
  else { dc.setPenWidth(2); dc.setStroke(argb(80, 0xffffff)); dc.drawArc(227, 227, L.ringR, CW, a0, a1); }
  if (f * e > .005) { dc.setPenWidth(3); dc.setStroke(argb(Math.round(230 * alpha), day ? 0xffd28a : 0xbfd0ff)); dc.drawArc(227, 227, L.ringR, CW, a0, pos); }
  dc.setStroke(argb(160, 0xffffff)); dc.setPenWidth(1.5);
  for (const a of [a0, 90, a1]) { const [x1, y1] = ringPoint(a, L.ringR - 5), [x2, y2] = ringPoint(a, L.ringR + 5); dc.drawLine(x1, y1, x2, y2); }
  const [x, y] = ringPoint(pos, L.ringR);
  if (day) { drawGlow(dc, x, y, 8, p[P_GLOW], alpha * (t >= 0 ? .8 + .25 * Math.sin(t * 2.2) : 1)); dc.setFill(argb(Math.round(255 * Math.max(.4, alpha)), p[P_SUN])); dc.fillCircle(x, y, 8); }
  else drawMoon(dc, p, x, y, sc.phase, Math.max(.45, alpha), sc.fullMoon);
}
function drawMoon(dc, p, x, y, phase, alpha, full) {
  const r = full ? 9 : 8, k = Math.cos(phase * 2 * Math.PI), dir = phase < .5 ? 1 : -1, lit = [];
  drawGlow(dc, x, y, r, full ? 0xd8e4ff : 0x9db4e0, alpha * (full ? 1.2 : .5));
  dc.setFill(argb(255, mix(p[P_ZEN], 0x3a4660, .6))); dc.fillCircle(x, y, r);
  for (let i = 0; i <= 16; i++) { const a = -Math.PI / 2 + Math.PI * i / 16; lit.push([x + dir * r * Math.cos(a), y + r * Math.sin(a)]); }
  for (let i = 16; i >= 0; i--) { const a = -Math.PI / 2 + Math.PI * i / 16; lit.push([x + dir * r * k * Math.cos(a), y + r * Math.sin(a)]); }
  dc.setFill(argb(Math.round(255 * alpha), 0xeef2f8)); dc.fillPolygon(lit);
}
// lower half: steps (left) and body battery (right) climb the ring from the bottom; labels follow the ring
function drawGaugeTracks(dc) {
  dc.setPenWidth(5); dc.setStroke(argb(255, TRACK)); dc.setFill(argb(255, TRACK));
  [L.steps, L.body].forEach((sp, i) => { dc.drawArc(227, 227, L.ringR, i === 0, sp[0], sp[1]); cap(dc, sp[0], 2.5); cap(dc, sp[1], 2.5); });
}
function gauge(dc, span, value, color, e, clockwise) {
  if (value <= 0 || e <= 0) return;
  const [a0, a1] = span, end = a0 + (clockwise ? -1 : 1) * Math.abs(a1 - a0) * clamp(value, 0, 1) * e;
  dc.setPenWidth(5); dc.setStroke(argb(255, color)); dc.drawArc(227, 227, L.ringR, clockwise, a0, end);
  dc.setFill(argb(255, color)); cap(dc, a0, 2.5); cap(dc, end, 2.5);
  dc.setFill(argb(70, color)); cap(dc, end, 6);
}
function drawGauges(dc, s, e, accent) {
  const sp = s.steps == null || !s.stepGoal ? 0 : s.steps / s.stepGoal;
  gauge(dc, L.steps, sp, sp >= 1 ? mix(accent, 0xffffff, .3) : accent, e, CW);
  const bb = s.bodyBattery == null ? 0 : s.bodyBattery / 100;
  gauge(dc, L.body, bb, bb < .25 ? 0xff7a66 : 0x5fd3bd, e, CCW);
}

// ------------------------------------------------------------------ text (Hud.mc)
function hm(sec) { return String(Math.floor(sec / 3600)).padStart(2, '0') + ':' + String(Math.floor(sec / 60) % 60).padStart(2, '0'); }
function iconHeart(dc, x, y, c) { dc.setFill(argb(255, c)); dc.fillCircle(x - 3.6, y - 2, 4.2); dc.fillCircle(x + 3.6, y - 2, 4.2); dc.fillPolygon([[x - 7.6, y - 1], [x + 7.6, y - 1], [x, y + 7]]); }
function iconFlame(dc, x, y, c) { dc.setFill(argb(255, c)); dc.fillPolygon([[x, y - 9], [x + 6, y - 1], [x + 5, y + 5], [x, y + 8], [x - 5, y + 5], [x - 6, y], [x - 3, y - 3], [x - 2, y + 1]]); dc.setFill(argb(255, mix(c, 0xffffff, .55))); dc.fillEllipse(x, y + 4, 2.2, 3); }
function iconBolt(dc, x, y, c) { dc.setFill(argb(255, c)); dc.fillPolygon([[x + 2, y - 9], [x - 6, y + 1], [x - 1, y + 1], [x - 3, y + 9], [x + 6, y - 2], [x + 1, y - 2], [x + 3, y - 9]]); }
function iconBattery(dc, x, y, level, c) {
  dc.setStroke(argb(255, c)); dc.setPenWidth(1.5); dc.drawRoundedRectangle(x - 10, y - 5, 18, 10, 2.5);
  dc.setFill(argb(255, c)); dc.fillRectangle(x + 8, y - 2, 2, 4); dc.fillRectangle(x - 8, y - 3, Math.max(1.5, 14 * level / 100), 6);
}
function iconHorizonSun(dc, x, y, up, c) { // half sun on a horizon line, arrow up for sunrise, down for sunset
  dc.setFill(argb(255, c)); dc.fillPolygon([...Array(9)].map((_, i) => [x + 6 * Math.cos(Math.PI * i / 8), y + 3 - 6 * Math.sin(Math.PI * i / 8)]));
  dc.setStroke(argb(255, c)); dc.setPenWidth(1.5); dc.drawLine(x - 9, y + 4, x + 9, y + 4);
  dc.fillPolygon(up ? [[x, y - 9], [x - 3, y - 5], [x + 3, y - 5]] : [[x, y - 4], [x - 3, y - 8], [x + 3, y - 8]]);
}
function iconWeather(dc, x, y, cls, night, c) {
  const sun = () => {
    if (night) { dc.setFill(argb(255, 0xe6ecf5)); dc.fillCircle(x - 2, y - 3, 6); dc.setFill(argb(255, 0)); dc.fillCircle(x + 1, y - 6, 5.5); return; }
    dc.setFill(argb(255, 0xffcf7a)); dc.fillCircle(x - 3, y - 3, 5); dc.setStroke(argb(255, 0xffcf7a)); dc.setPenWidth(1.6);
    for (let i = 0; i < 8; i++) { const a = i * Math.PI / 4; dc.drawLine(x - 3 + Math.cos(a) * 7.5, y - 3 + Math.sin(a) * 7.5, x - 3 + Math.cos(a) * 10, y - 3 + Math.sin(a) * 10); }
  };
  const cloud = cy => { dc.setFill(argb(255, c)); dc.fillCircle(x - 4, cy + 1, 4.5); dc.fillCircle(x + 1.5, cy - 2, 6); dc.fillCircle(x + 6.5, cy + 1.5, 4); dc.fillRoundedRectangle(x - 8.5, cy + 1, 19, 5, 2.5); };
  if (cls === 0) return sun();
  if (cls === 1) { sun(); return cloud(y + 3); }
  if (cls === 5) { dc.setStroke(argb(255, c)); dc.setPenWidth(2); for (let i = 0; i < 3; i++) dc.drawLine(x - 9 + i * 2, y - 5 + i * 5, x + 9 - i * 2, y - 5 + i * 5); return; }
  cloud(y - 3);
  if (cls === 3 || cls === 6) { dc.setStroke(argb(255, 0x9cc8ff)); dc.setPenWidth(1.6); for (let i = 0; i < 3; i++) dc.drawLine(x - 5 + i * 5, y + 6, x - 7 + i * 5, y + 10); }
  if (cls === 4) { dc.setFill(argb(255, 0xffffff)); for (let i = 0; i < 3; i++) dc.fillCircle(x - 5 + i * 5, y + 8 + (i % 2) * 2, 1.4); }
  if (cls === 6) iconBolt(dc, x + 1, y + 6, 0xffd36a);
}
function timeText(s) { return String(s.is24 ? s.hour : (s.hour + 11) % 12 + 1).padStart(2, '0') + ':' + String(s.min).padStart(2, '0'); }
const count = (v, e) => v == null ? '--' : String(Math.round(v * e));
// the text and the labels along the ring; e < 1 during the intro: the time slides up and the readings count up from zero
function drawHud(dc, s, sc, e) {
  const accent = sc.accent;
  dc.setColor(mix(accent, 0xffffff, .2)); dc.drawRadialText(227, 227, 'SmallFont', 'STEP ' + count(s.steps, e), 234, L.labelR, CCW);
  dc.setColor(0x8fd6c6); dc.drawRadialText(227, 227, 'SmallFont', 'BODY ' + count(s.bodyBattery, e), 306, L.labelR, CCW);
  dc.setColor(0xf6f4ee); dc.drawText(L.timeX, L.timeBase - FONTS.TimeFont.base + 16 * (1 - e), 'TimeFont', timeText(s), 1);
  // left: weather over temperature; right: clock mode over seconds (seconds are drawn every frame)
  iconWeather(dc, L.sideX, 246, s.weatherClass, !sc.day, 0xc9d6e6);
  dc.setColor(0xf2efe8); dc.drawText(L.sideX, 260, 'ValueFont', s.temp == null ? '--' : Math.round(s.temp) + '°', 1);
  dc.setColor(0x9aa6b2); dc.drawText(L.sideRX, 236, 'SmallFont', s.is24 ? '24H' : (s.hour < 12 ? 'AM' : 'PM'), 1);
  // the date: 七曜 seal, weekday and date, then 节气 (on its day) or 农历
  const term = FESTIVAL_NAMES[sc.fest] || Cal.term(s.year, s.month, s.day), lunar = Cal.lunarText(s.year, s.month, s.day), extra = term || lunar || '';
  const date = `周${'日一二三四五六'[s.weekday - 1]} ${String(s.month).padStart(2, '0')}/${String(s.day).padStart(2, '0')}`;
  const cy = L.dateY + FONTS.TextFont.base - FONTS.TextFont.cap / 2, seal = 26, w1 = dc.textWidth(date, 'TextFont'), w2 = extra ? dc.textWidth(extra, 'TextFont') + 12 : 0;
  const left = 227 - (seal + 9 + w1 + w2) / 2, wk = s.weekday - 1;
  dc.setFill(argb(255, WEEK_COLORS[wk])); dc.fillRoundedRectangle(left, cy - seal / 2, seal, seal, 6);
  dc.setColor(0x16110a); dc.drawText(left + seal / 2, cy - FONTS.SmallFont.base + FONTS.SmallFont.cap / 2, 'SmallFont', '日月火水木金土'[wk], 1);
  dc.setColor(0xf2efe8); dc.drawText(left + seal + 9, L.dateY, 'TextFont', date, 2);
  if (extra) { dc.setColor(term ? accent : 0xc9b48e); dc.drawText(left + seal + 9 + w1 + 12, L.dateY, 'TextFont', extra, 2); }
  // move alert: hatched bars either side of the date
  if (s.moveBar >= 1) { dc.setFill(argb(255, accent)); for (let i = 0; i < 4; i++) { dc.fillPolygon([[left - 40 + i * 7, cy + 5], [left - 36 + i * 7, cy - 5], [left - 33 + i * 7, cy - 5], [left - 37 + i * 7, cy + 5]]); const r = 227 + (227 - left) + 9; dc.fillPolygon([[r + i * 7, cy + 5], [r + 4 + i * 7, cy - 5], [r + 7 + i * 7, cy - 5], [r + 3 + i * 7, cy + 5]]); } }
  // one row of readings: heart rate and active calories (the sun ring already shows sunrise to sunset)
  const items = [[iconHeart, 0xff7a6e, s.hr ?? '--'], [iconFlame, 0xffa45a, s.calories ?? '--']];
  const iw = 20, gap = 6, sp = 28;
  let total = -sp; for (const it of items) total += iw + gap + dc.textWidth(String(it[2]), 'ValueFont') + sp;
  let x = 227 - total / 2; const iy = L.infoY + FONTS.ValueFont.base - FONTS.ValueFont.cap / 2;
  // laid out from the final values so nothing shifts while they count up; the heart is left to drawPulse
  for (const [icon, c, v] of items) {
    if (icon === iconHeart) { sc.heartX = x + iw / 2; sc.heartY = iy; } else icon(dc, x + iw / 2, iy, c);
    dc.setColor(0xe8e6e0); dc.drawText(x + iw + gap, L.infoY, 'ValueFont', typeof v === 'number' ? count(v, e) : v, 2); x += iw + gap + dc.textWidth(String(v), 'ValueFont') + sp;
  }
  // watch battery between the two gauges
  const low = s.battery <= (s.batteryLimit ?? 20), bc = low ? 0xff6a55 : s.charging ? 0x8fe39a : 0xa9b4c0, bt = Math.round(s.battery) + '%';
  const bw = 22 + dc.textWidth(bt, 'SmallFont'), bx = 227 - bw / 2;
  const level = Math.round(s.battery * e);
  iconBattery(dc, bx + 10, L.batteryY + FONTS.SmallFont.base - FONTS.SmallFont.cap / 2, level, bc);
  dc.setColor(bc); dc.drawText(bx + 24, L.batteryY, 'SmallFont', level + '%', 2);
}
// the heart beside the heart rate, beating at the measured rate while awake (t < 0: still)
function drawPulse(dc, s, sc, t) {
  let k = 1;
  if (t >= 0 && s.hr > 0) { const u = 1 - (t * s.hr / 60) % 1; k = 1 + .24 * u ** 4; }
  const x = sc.heartX, y = sc.heartY;
  dc.setFill(argb(255, 0xff7a6e)); dc.fillCircle(x - 3.6 * k, y - 2 * k, 4.2 * k); dc.fillCircle(x + 3.6 * k, y - 2 * k, 4.2 * k);
  dc.fillPolygon([[x - 7.6 * k, y - k], [x + 7.6 * k, y - k], [x, y + 7 * k]]);
}
function drawSeconds(dc, s) { dc.setColor(0xf2efe8); dc.drawText(L.sideRX, 256, 'ValueFont', String(s.sec).padStart(2, '0'), 1); }

// ------------------------------------------------------------------ calendar (Cal.mc)
const TERMS = ['小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨', '立夏', '小满', '芒种', '夏至', '小暑', '大暑', '立秋', '处暑', '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至'];
const Cal = {
  term(y, m, d) {
    const D = DATA.cal; if (y < D.termFirst || y >= D.termFirst + D.terms.length / 3) return null;
    const base = (y - D.termFirst) * 3;
    for (let j = (m - 1) * 2; j < m * 2; j++) { const day = ((D.terms[base + (j >> 3)] >> (3 * (j & 7))) & 7) + (j % 2 ? 18 : 3); if (day === d) return TERMS[j]; }
    return null;
  },
  doy(y, m, d) { return (Date.UTC(y, m - 1, d) - Date.UTC(y, 0, 1)) / 86400000 + 1; },
  lunar(y, m, d) { // [month, day, leap?]
    const D = DATA.cal, ny = w => ((w >> 17) & 31) + 21;
    let idx = y - D.lunarFirst; if (idx < 0 || idx >= D.lunar.length) return null;
    let off = this.doy(y, m, d) - ny(D.lunar[idx]);
    if (off < 0) { idx--; if (idx < 0) return null; off = this.doy(y, m, d) + this.doy(y - 1, 12, 31) - ny(D.lunar[idx]); }
    const w = D.lunar[idx], leap = (w >> 13) & 15;
    for (let i = 0, month = 1; i < (leap ? 13 : 12); i++) {
      const len = (w >> i) & 1 ? 30 : 29, isLeap = leap > 0 && i === leap;
      if (off < len) return [isLeap ? leap : month, off + 1, isLeap];
      off -= len; if (!isLeap) month++;
    }
    return null;
  },
  lunarText(y, m, d) {
    const l = this.lunar(y, m, d); if (!l) return null;
    const n = '一二三四五六七八九', day = l[1] === 10 ? '初十' : l[1] === 20 ? '二十' : l[1] === 30 ? '三十' : ['初', '十', '廿'][Math.floor(l[1] / 10)] + n[l[1] % 10 - 1];
    return (l[2] ? '闰' : '') + '正二三四五六七八九十冬腊'[l[0] - 1] + '月' + day;
  },
};

// ------------------------------------------------------------------ face (Scene.mc / MountainView.mc)
let DATA, Geo, FONTS;
const Face = {
  async load(data, fontUrl) {
    DATA = typeof data === 'object' ? data : await fetch(data).then(r => r.json());
    Geo = DATA.scene; FONTS = DATA.fonts;
    const images = {}, cache = {};
    await Promise.all(Object.keys(FONTS).map(n => new Promise((res, rej) => { const im = new Image(); im.onload = res; im.onerror = rej; im.src = fontUrl(n); images[n] = im; })));
    for (const n of Object.keys(images)) { const g = FONTS[n].glyphs; FONTS[n].cap = g['步'] ? g['步'][3] - 2 : g['0'] ? g['0'][3] - 2 : FONTS[n].lineHeight * .55; }
    FONTS.tinted = (n, color) => { // glyph atlas recoloured once per font+colour, like a Dc foreground colour
      const key = n + color; if (cache[key]) return cache[key];
      const im = images[n], cv = document.createElement('canvas'); cv.width = im.width; cv.height = im.height;
      const x = cv.getContext('2d'); x.drawImage(im, 0, 0); x.globalCompositeOperation = 'source-in'; x.fillStyle = Dc.css(0xff000000 | color); x.fillRect(0, 0, cv.width, cv.height);
      return cache[key] = cv;
    };
  },
  // everything about the scene that only changes once a minute (Scene.prepare)
  prepare(s) {
    const now = s.hour * 3600 + s.min * 60 + s.sec, rise = s.sunrise ?? 6 * 3600, set = s.sunset ?? 18 * 3600;
    let [alt, evening] = sunState(now, rise, set);
    alt = Math.round(alt); // whole degrees: the watch repaints its landscape layer only when the light has visibly changed
    let f = now >= rise && now <= set ? (now - rise) / (set - rise) : ((now - set + 86400) % 86400) / (86400 - (set - rise));
    if (s.sky === 1) { alt = -1; evening = false; f = .04; } else if (s.sky === 2) { alt = 30; f = .4; } else if (s.sky === 3) { alt = 2.5; evening = true; f = .95; } else if (s.sky === 4) { alt = -30; f = .7; }
    const fx = s.weatherFx === false ? 0 : s.weatherClass, overcast = [0, .15, .7, .85, .6, .55, .95][fx];
    const fest = s.festivals === false ? 0 : festivalOf(s), season = s.season ?? seasonOf(s.month);
    const p = palette(alt, evening, overcast, fx === 3 || fx === 6);
    festivalPalette(p, fest);
    const day = alt > -4, phase = moonPhase(s.year, s.month, s.day), starA = clamp((-alt - 3) / 9, 0, 1) * (1 - overcast);
    return {
      alt, f, day, fx, overcast, p, starA, phase, fest, season, sunLeft: f < .5, accent: ACCENTS[s.accent || 0],
      goal: s.steps != null && s.stepGoal && s.steps >= s.stepGoal,
      stress: s.stress != null && s.stress >= (s.stressLimit ?? 70),
      lowBattery: s.battery <= (s.batteryLimit ?? 20) || s.charging,
      fullMoon: !day && Math.abs(phase - .5) < .04 && fx < 2,
      aurora: !day && fx < 2 && season === 3 && fest === 0 && starA > .5,
    };
  },
  // a: {intro 0..1, t seconds since wake, meteorAt}. The first block is what the watch caches once a minute.
  render(ctx, s, a) {
    const dc = new Dc(ctx, FONTS); dc.clear();
    const sc = this.prepare(s); s.alt = sc.alt;
    if (s.aod) return this.renderAod(dc, s, sc);
    const { p, fx, day, overcast, fest } = sc, e = ease(a.intro), t = a.t, rich = s.motion === 0, drift = rich ? t : 0;
    // ---- landscape layer (cached on the watch until the light changes); it rises into place during the intro
    const dy = Math.round(26 * (1 - e)), split = Geo.horizon + 36;
    if (dy > 0) { ctx.save(); ctx.beginPath(); ctx.rect(0, 0, 454, split); ctx.clip(); ctx.translate(0, dy); }
    this.paintLand(dc, s, sc);
    if (dy > 0) { ctx.restore(); ctx.save(); ctx.beginPath(); ctx.rect(0, split, 454, 454 - split); ctx.clip(); this.paintLand(dc, s, sc); ctx.restore(); }
    // ---- text layer (cached every minute; drawn live while the intro counts up)
    drawHud(dc, s, sc, e);
    // ---- moving parts
    drawClouds(dc, p, [0, .35, .8, .9, .75, .3, 1][fx], drift);
    if (fx === 5) drawFog(dc, p, drift);
    this.drawMoving(dc, s, sc, a, e);
  },
  paintLand(dc, s, sc) {
    const { p, fx, day, overcast } = sc;
    drawSky(dc, p);
    if (sc.starA > .3) drawMilkyWay(dc, sc.starA * (sc.fullMoon ? .6 : 1));
    if (sc.aurora) drawAurora(dc, sc.starA);
    if (sc.goal && day && fx < 3) drawRainbow(dc, 1 - overcast);
    if (sc.fullMoon) drawGlow(dc, 227, 110, 40, 0xc8d8ff, .35);
    drawFestivalSky(dc, sc);
    drawLand(dc, s, sc);
    drawGroundFade(dc, p, sc.season);
    if (fx === 5) haze(dc, p[P_HOR], 90, 215, 0, 120);
    drawRimShade(dc);
    drawGaugeTracks(dc);
  },
  drawMoving(dc, s, sc, a, e) {
    const { fx, day, fest } = sc, t = a.t, rich = s.motion === 0;
    drawStars(dc, s, sc.starA, t, e);
    if (a.meteorAt != null && sc.starA > .5 && rich) drawMeteor(dc, a.meteorAt, t);
    if (wantsFireworks(sc)) drawFireworks(dc, s, t, fireworkSlots(sc));
    if (fest === 2) drawSkyLanterns(dc, s, t);
    if (fest === 8) drawHearts(dc, s, t);
    if (fest === 9) drawBalloons(dc, s, t);
    if ((fest === 7 || fest === 13) && day) drawFalling(dc, s, t, 0);
    if (fest === 17 || fest === 16) drawFalling(dc, s, t, 1);
    if (fest === 21) drawFalling(dc, s, t, 2);
    if (fest === 14) { drawKite(dc, s, t); if (fx < 3) drawRain(dc, s, t, false); }
    if (fest === 15) drawBeans(dc, s, t);
    if (fest === 18) drawKoinobori(dc, s, t);
    if (fest === 5) drawBats(dc, s, t);
    if (day && fx < 2 && rich && !fest) drawBirds(dc, s, t);
    if (!day || (s.temp != null && s.temp < 12)) drawSmoke(dc, s, t);
    if (sc.stress) drawVolcano(dc, s, t);
    if (sc.lowBattery) drawBolt(dc, s, t);
    if (fx === 3 || fx === 6) drawRain(dc, s, t, fx === 6);
    if (fx === 4 || (fest === 4 && fx < 3)) drawSnow(dc, s, t);
    if (fx === 6) drawStorm(dc, s, t);
    drawPulse(dc, s, sc, rich ? t : -1);
    drawSkyRing(dc, sc, e, rich ? t : -1);
    drawGauges(dc, s, e, sc.accent);
    drawSeconds(dc, s);
    if (a.intro < .6) { dc.setFill(argb(Math.round(255 * (1 - a.intro / .6)), 0)); dc.fillRectangle(0, 0, 454, 454); }
  },
  // always-on: the whole scene in fine line art, a few percent of pixels lit, shifted every minute
  renderAod(dc, s, sc) {
    const [dx, dy] = [[0, 0], [4, 3], [-3, 5], [5, -3], [-4, -4]][s.min % 5];
    const outline = (pts, c, close) => { dc.setStroke(argb(255, c)); dc.setPenWidth(1); for (let i = 0; i < pts.length - (close ? 0 : 1); i++) { const a = pts[i], b = pts[(i + 1) % pts.length]; dc.drawLine(a[0] + dx, a[1] + dy, b[0] + dx, b[1] + dy); } };
    // dotted sun path with the sun or moon as a small ring
    const [a0, a1] = L.sunSpan;
    dc.setFill(argb(255, 0x2a3038));
    for (let a = a0; a >= a1; a -= 6) { const [x, y] = ringPoint(a, L.ringR); dc.fillCircle(x + dx, y + dy, 1); }
    const [sx, sy] = ringPoint(a0 - (a0 - a1) * clamp(sc.f, 0, 1), L.ringR);
    dc.setStroke(argb(255, sc.day ? 0x8a6a3a : 0x6a7a9a)); dc.setPenWidth(1.5); dc.drawCircle(sx + dx, sy + dy, 5);
    // a scatter of faint stars
    dc.setFill(argb(255, 0x3a4250));
    for (let i = 0; i < 16; i++) { const x = 60 + rnd(i, 81) * 334, y = 40 + rnd(i, 82) * 110; if (skyOpen(x, y)) dc.fillCircle(x + dx, y + dy, .8); }
    // the landscape as line art
    outline(Geo.farRidge, 0x232a33, false);
    for (const [role, pts] of Geo.shapes) {
      if (role === 'body') outline(pts, 0x3c4856, false);
      if (role === 'snowL' || role === 'snowR') outline(pts, 0x56606c, true);
      if (role === 'tree' && pts[0][1] < 200) outline(pts, 0x262d36, true);
    }
    outline(Geo.cabin, 0x34404c, true);
    if (s.notifications > 0) { dc.setFill(argb(255, 0x7a5a2a)); dc.fillPolygon(Geo.window.map(([x, y]) => [x + dx, y + dy])); }
    const hz = Geo.horizon + 2; dc.setStroke(argb(255, 0x1c2128)); dc.drawLine(70 + dx, hz + dy, 384 + dx, hz + dy);
    // time, date with its seal, two readings
    dc.setColor(0x8a929c); dc.drawText(L.timeX + dx, L.timeBase - FONTS.TimeLine.base + dy, 'TimeLine', timeText(s), 1);
    const wk = s.weekday - 1, date = `周${'日一二三四五六'[wk]} ${String(s.month).padStart(2, '0')}/${String(s.day).padStart(2, '0')}`;
    const cy = L.dateY + FONTS.TextFont.base - FONTS.TextFont.cap / 2, w = dc.textWidth(date, 'TextFont'), left = 227 - (26 + 9 + w) / 2;
    dc.setStroke(argb(255, mix(WEEK_COLORS[wk], 0, .5))); dc.setPenWidth(1.5); dc.drawRoundedRectangle(left + dx, cy - 13 + dy, 26, 26, 6);
    dc.setColor(mix(WEEK_COLORS[wk], 0, .45)); dc.drawText(left + 13 + dx, cy - FONTS.SmallFont.base + FONTS.SmallFont.cap / 2 + dy, 'SmallFont', '日月火水木金土'[wk], 1);
    dc.setColor(0x6a727c); dc.drawText(left + 35 + dx, L.dateY + dy, 'TextFont', date, 2);
    dc.setColor(0x4e5660); dc.drawText(227 + dx, L.infoY + 4 + dy, 'SmallFont', `HR ${s.hr ?? '--'}  ·  ${Math.round(s.battery)}%`, 1);
  },
};
if (typeof module !== 'undefined') module.exports = { Face };
