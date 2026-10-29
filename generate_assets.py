"""山境 v2 资源生成器。

一处定义，两处使用：字体、山景几何、农历/节气表同时输出给
  - 原生表盘：resources/fonts/*、source/Generated.mc
  - 浏览器预览：preview-data.json
保证预览与手表画面用的是同一份数据。

依赖：Python 3 + Pillow；农历表需要 Node（ICU 中国历），节气为天文计算。
字体：时间数字沿用 v1 的 Impact（Windows 自带的商业字体，不随仓库分发：克隆后由本脚本从本机 Impact 生成）；
中文与数据用 Noto Sans SC（SIL OFL，生成的字库已在仓库里，本机没装这个字体时沿用仓库里的）。
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
import datetime, json, math, subprocess

ROOT = Path(__file__).resolve().parent
FONTS = Path('C:/Windows/Fonts')

# ---------------------------------------------------------------- fonts

WEEK = '一二三四五六日'
LUNAR = '正二三四五六七八九十冬腊月初廿闰'
TERMS = '小寒大寒立春雨水惊蛰春分清明谷雨立夏小满芒种夏至小暑大暑立秋处暑白露秋分寒露霜降立冬小雪大雪冬至'
WORDS = '周年月日出落上午下午活动一下充电中低电量勿扰步数身体手机条心率海拔卡路里压力火水木金土曜山境春节元宵中秋圣诞万圣满除夕正情人儿童端午七重阳跨清明分女赏樱男孩盂兰盆红叶复活'
CJK = ''.join(sorted(set(WEEK + LUNAR + TERMS + WORDS)))
ASCII = ''.join(chr(i) for i in range(32, 127))


def font_spec(file, instance, size):
    f = ImageFont.truetype(str(FONTS / file), size)
    if instance:
        f.set_variation_by_name(instance)
    return f


def build_font(name, file, instance, size, chars, tabular=False, outline=0):
    """Rasterise glyphs tightly, pack into an atlas, write AngelCode .fnt + metrics."""
    font = font_spec(file, instance, size)
    ascent, descent = font.getmetrics()
    pad = 1 + outline
    glyphs = []
    cell = 0
    if tabular:
        cell = max(round(font.getlength(c)) for c in '0123456789')
    for ch in chars:
        adv = round(font.getlength(ch))
        l, t, r, b = font.getbbox(ch, anchor='ls')
        if ch == ' ' or r <= l:
            glyphs.append((ch, None, 0, 0, adv))
            continue
        w, h = r - l + 2 * pad, b - t + 2 * pad
        mask = Image.new('L', (w, h), 0)
        ImageDraw.Draw(mask).text((pad - l, pad - t), ch, font=font, fill=255, anchor='ls')
        if outline:
            outer = mask.filter(ImageFilter.MaxFilter(2 * outline - 1 if outline > 1 else 3))
            inner = mask.filter(ImageFilter.MinFilter(3))
            mask = ImageChops.subtract(outer, inner)
        xo = l - pad
        if tabular and ch.isdigit():
            xo = round((cell - (r - l)) / 2) - pad
            adv = cell
        glyphs.append((ch, mask, xo, ascent + t - pad, adv))
    # shelf packing
    width = 512 if size > 40 else 256
    x = y = shelf = 0
    places = {}
    for ch, mask, *_ in sorted(glyphs, key=lambda g: -(g[1].height if g[1] else 0)):
        if mask is None:
            continue
        if x + mask.width > width:
            x, y, shelf = 0, y + shelf + 1, 0
        places[ch] = (x, y)
        x += mask.width + 1
        shelf = max(shelf, mask.height)
    height = y + shelf + 1
    atlas = Image.new('RGBA', (width, height), (255, 255, 255, 0))
    lines = [f'info face="{name}" size={size} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1',
             f'common lineHeight={ascent + descent} base={ascent} scaleW={width} scaleH={height} pages=1 packed=0',
             f'page id=0 file="{name}.png"', f'chars count={len(glyphs)}']
    metrics = {}
    for ch, mask, xo, yo, adv in glyphs:
        if mask is None:
            px = py = w = h = 0
        else:
            px, py = places[ch]
            w, h = mask.size
            white = Image.new('RGBA', mask.size, (255, 255, 255, 0))
            white.putalpha(mask)
            atlas.paste(white, (px, py))
        lines.append(f'char id={ord(ch)} x={px} y={py} width={w} height={h} xoffset={xo} yoffset={yo} xadvance={adv} page=0 chnl=15')
        metrics[ch] = [px, py, w, h, xo, yo, adv]
    atlas.save(ROOT / f'resources/fonts/{name}.png')
    (ROOT / f'resources/fonts/{name}.fnt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return {'lineHeight': ascent + descent, 'base': ascent, 'glyphs': metrics}


def read_font(name):
    """Metrics of an atlas already in resources/fonts, for a source font that isn't installed here."""
    lines = (ROOT / f'resources/fonts/{name}.fnt').read_text(encoding='utf-8').splitlines()
    fields = lambda line: dict(p.split('=', 1) for p in line.split()[1:] if '=' in p)
    common = fields(next(line for line in lines if line.startswith('common ')))
    glyphs = {}
    for line in lines:
        if line.startswith('char '):
            c = fields(line)
            glyphs[chr(int(c['id']))] = [int(c[k]) for k in ('x', 'y', 'width', 'height', 'xoffset', 'yoffset', 'xadvance')]
    return {'lineHeight': int(common['lineHeight']), 'base': int(common['base']), 'glyphs': glyphs}


def fonts():
    specs = [
        # name,        file,                 instance,  size, chars,                     tabular, outline
        ('TimeFont', 'impact.ttf', None, 96, '0123456789:', True, 0),
        ('TimeLine', 'impact.ttf', None, 96, '0123456789:', True, 1),
        ('TextFont', 'NotoSansSC-VF.ttf', 'Medium', 25, ASCII + '°·' + CJK, False, 0),
        ('ValueFont', 'NotoSansSC-VF.ttf', 'Medium', 27, ' 0123456789,.-%°:', False, 0),
        ('SmallFont', 'NotoSansSC-VF.ttf', 'Medium', 20, ASCII + '°·' + CJK, False, 0),
    ]
    out = {}
    xml = []
    for name, file, inst, size, chars, tab, outl in specs:
        if (FONTS / file).exists():
            out[name] = build_font(name, file, inst, size, chars, tab, outl)
        elif (ROOT / f'resources/fonts/{name}.fnt').exists():
            print(f'{FONTS / file} not installed: keeping resources/fonts/{name}.fnt')
            out[name] = read_font(name)
        else:
            raise SystemExit(f'{name} is built from {FONTS / file}, which is not installed here')
        xml.append(f'  <font id="{name}" filename="{name}.fnt" antialias="true"/>')
    (ROOT / 'resources/fonts/fonts.xml').write_text('<fonts>\n' + '\n'.join(xml) + '\n</fonts>\n', encoding='utf-8')
    return out


# ---------------------------------------------------------------- scene geometry
# 454 x 454 round screen. The landscape is Astra's v1 drawing (the 望山-X direction), drawn in v1
# coordinates below and then lifted so the horizon sits at y = 215 (about 47% down, like the
# reference), which leaves the lower half room to breathe. Colours come from the live palette.


def lift(points):
    return [(x, round(0.9 * y - 24)) for x, y in points]


def pine(x, base, h, w=8):
    """A two-tier pine, base on the ground line."""
    k = w / 8
    return [(x, base - h), (x - 4 * k, base - h + 10), (x - 2 * k, base - h + 10), (x - w, base - 4), (x - 3 * k, base - 4),
            (x - 3 * k, base + 4), (x + 3 * k, base + 4), (x + 3 * k, base - 4), (x + w, base - 4), (x + 2 * k, base - h + 10),
            (x + 4 * k, base - h + 10)]


def edge_at(line, x):
    for (x0, y0), (x1, y1) in zip(line, line[1:]):
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * (x - x0) / max(1e-6, x1 - x0)
    return line[-1][1]


HILLS = [(37, 251), (92, 222), (129, 230), (167, 211), (203, 238), (245, 218), (281, 235), (330, 208), (367, 220), (421, 211), (429, 259), (26, 259)]
SHAPES = [
    ('far', [(22, 225), (73, 166), (101, 187), (153, 134), (204, 194), (265, 151), (316, 185), (361, 153), (432, 223), (432, 246), (22, 246)]),
    ('range', [(30, 244), (100, 192), (130, 209), (185, 157), (235, 202), (284, 164), (336, 213), (378, 189), (425, 229), (425, 251), (30, 251)]),
    ('body', [(77, 251), (150, 188), (180, 195), (244, 104), (272, 139), (288, 132), (375, 247)]),
    ('snowL', [(169, 211), (244, 104), (259, 125), (243, 119), (221, 156), (226, 133), (207, 163), (208, 147), (188, 183), (190, 169)]),
    ('snowR', [(244, 104), (272, 139), (288, 132), (302, 154), (289, 147), (293, 166), (272, 151), (256, 173), (265, 149), (246, 163), (254, 140), (235, 160), (245, 130), (227, 151)]),
    ('streakL', [(212, 176), (229, 157), (218, 179), (215, 197), (200, 218), (204, 196), (189, 212)]),
    ('streakR', [(266, 166), (280, 157), (297, 182), (286, 176), (294, 194), (278, 184), (261, 210), (274, 183)]),
    ('hills', HILLS),
]
# a second, distant row of small pines along the hill tops
for x, h in [(138, 11), (147, 14), (156, 10), (164, 13), (296, 10), (306, 13), (316, 15), (324, 11), (340, 12), (352, 9)]:
    SHAPES.append(('treeFar', pine(x, round(edge_at(HILLS, x)) + 3, h, 5)))
SHAPES.append(('ground', [(16, 249), (65, 235), (102, 245), (154, 235), (190, 252), (244, 242), (298, 250), (353, 233), (409, 245), (438, 239), (438, 266), (16, 266)]))
for x, y, h, w in [(30, 247, 16, 6), (48, 244, 22, 8), (69, 244, 32, 9), (87, 250, 20, 8), (104, 251, 14, 6), (118, 252, 10, 5),
                   (344, 248, 15, 6), (361, 248, 23, 8), (383, 248, 35, 9), (402, 250, 26, 8), (420, 247, 19, 7), (433, 246, 13, 5)]:
    SHAPES.append(('tree', pine(x, y, h, w)))
SHAPES = [(role, lift(pts)) for role, pts in SHAPES]
# the sky fills the whole dial, so the wide layers run out to the screen edge
for role, pts in SHAPES:
    if role in ('far', 'range', 'hills', 'ground'):
        lo, hi = min(p[0] for p in pts), max(p[0] for p in pts)
        pts[:] = [(0 if x == lo else 454 if x == hi else x, y) for x, y in pts]
# cabin by the right-hand pines: chimney, house, door and a window that lights up for messages. It stands
# 6 px below v1's spot, on the near ground with the big pines rather than up on the hill crest behind them.
CABIN_DROP = 6


def cabin(points):
    return [(x, y + CABIN_DROP) for x, y in lift(points)]


CHIMNEY = cabin([(331, 224), (331, 216), (335, 216), (335, 227)])
CABIN = cabin([(318, 242), (318, 230), (315, 230), (328, 220), (341, 230), (338, 230), (338, 242)])
CABIN_DOOR = cabin([(321, 242), (321, 235), (325, 235), (325, 242)])
CABIN_WINDOW = cabin([(329, 232), (335, 232), (335, 237), (329, 237)])
SMOKE = cabin([(333, 214)])[0]
LAVA = lift([(242, 112), (249, 119), (241, 143), (250, 163), (239, 188), (243, 165), (234, 146)])
BOLT = lift([(349, 102), (339, 121), (347, 121), (341, 137), (359, 116), (350, 116)])
APEX = lift([(244, 104)])[0]
HORIZON = 215
# outline of the main massif: lit ridges (left in the morning, right in the afternoon) and the always-on drawing
RIDGE = lift([(77, 251), (150, 188), (180, 195), (244, 104), (272, 139), (288, 132), (375, 247)])
FAR_RIDGE = [p for p in SHAPES[0][1][:-2]]


def skyline():
    """Top edge of the land per 2-px column (stars and sun are only drawn above it)."""
    img = Image.new('L', (454, 454), 0)
    d = ImageDraw.Draw(img)
    for role, pts in SHAPES:
        d.polygon(pts, fill=255)
    out = []
    for x in range(0, 454, 2):
        y = next((y for y in range(454) if img.getpixel((x, y))), HORIZON)
        out.append(min(y, HORIZON))
    return out


SCENE = {
    'horizon': HORIZON, 'shapes': SHAPES, 'cabin': CABIN, 'chimney': CHIMNEY, 'door': CABIN_DOOR, 'window': CABIN_WINDOW,
    'smoke': SMOKE, 'lava': LAVA, 'bolt': BOLT, 'apex': APEX, 'ridge': RIDGE, 'farRidge': FAR_RIDGE, 'skyline': skyline(),
}


ROLE_IDS = ['far', 'range', 'body', 'snowL', 'snowR', 'streakL', 'streakR', 'hills', 'ground', 'tree', 'treeFar']


def flat(points):
    return [v for p in points for v in p]


# ---------------------------------------------------------------- calendar

TERM_NAMES = ['小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨', '立夏', '小满', '芒种', '夏至',
              '小暑', '大暑', '立秋', '处暑', '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至']
CAL_FIRST, CAL_LAST = 2024, 2050


def _jd(dt):
    y, m = dt.year, dt.month
    d = dt.day + (dt.hour + dt.minute / 60 + dt.second / 3600) / 24
    if m <= 2:
        y, m = y - 1, m + 12
    a = y // 100
    return int(365.25 * (y + 4716)) + int(30.6001 * (m + 1)) + d + 2 - a + a // 4 - 1524.5


def _sun_longitude(jde):
    t = (jde - 2451545.0) / 36525
    l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
    m = math.radians(357.52911 + 35999.05029 * t - 0.0001537 * t * t)
    c = ((1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(m) + (0.019993 - 0.000101 * t) * math.sin(2 * m)
         + 0.000289 * math.sin(3 * m))
    om = math.radians(125.04 - 1934.136 * t)
    return (l0 + c - 0.00569 - 0.00478 * math.sin(om)) % 360


def solar_term_day(year, index):
    """Day of month (Beijing time) of solar term `index` (0 = 小寒) in `year`."""
    lon = (285 + 15 * index) % 360
    month = index // 2 + 1
    jd = _jd(datetime.datetime(year, month, 6 if index % 2 == 0 else 21))
    for _ in range(60):
        delta = (lon - _sun_longitude(jd) + 180) % 360 - 180
        jd += delta * 365.2422 / 360
        if abs(delta) < 1e-8:
            break
    delta_t = 69 + (year - 2020) * 0.8  # seconds, TT - UT
    utc = datetime.datetime(2000, 1, 1, 12) + datetime.timedelta(days=jd - 2451545.0, seconds=-delta_t)
    local = utc + datetime.timedelta(hours=8)
    assert local.month == month, (year, index, local)
    return local.day


def solar_terms():
    """Three 24-bit words per year: 8 terms x 3 bits. 节 days start at 3, 中气 days at 18."""
    words, table = [], {}
    for year in range(CAL_FIRST, CAL_LAST + 1):
        days = [solar_term_day(year, i) for i in range(24)]
        table[year] = days
        packed = [0, 0, 0]
        for i, day in enumerate(days):
            off = day - (3 if i % 2 == 0 else 18)
            assert 0 <= off <= 7, (year, i, day)
            packed[i // 8] |= off << (3 * (i % 8))
        words += packed
    return words, table


LUNAR_JS = r"""
const f = new Intl.DateTimeFormat('zh-CN-u-ca-chinese', {timeZone: 'UTC', month: 'numeric', day: 'numeric'});
const out = {};
const start = Date.UTC(%d, 0, 1), end = Date.UTC(%d, 0, 1);
let cur = null;
for (let t = start; t < end; t += 86400000) {
  const p = Object.fromEntries(f.formatToParts(new Date(t)).map(x => [x.type, x.value]));
  if (p.day === '1') { cur = {start: t, month: p.month}; (out.months ||= []).push(cur); }
}
console.log(JSON.stringify(out));
"""


def lunar_years():
    """Per lunar year one Number: bits 0-12 month lengths (1 = 30 days), 13-16 leap month, 17-21 new-year offset."""
    js = LUNAR_JS % (CAL_FIRST - 1, CAL_LAST + 2)
    raw = json.loads(subprocess.run(['node', '-e', js], capture_output=True, text=True, encoding='utf-8', check=True).stdout)
    months = raw['months']
    years, words = [], []
    for i, m in enumerate(months):
        if m['month'] == '1':  # 正月初一
            years.append(i)
    for yi in range(len(years) - 1):
        a, b = years[yi], years[yi + 1]
        ny = datetime.datetime(1970, 1, 1) + datetime.timedelta(milliseconds=months[a]['start'])
        if not CAL_FIRST - 1 <= ny.year <= CAL_LAST:
            continue
        lens, leap = 0, 0
        for k in range(a, b):
            length = round((months[k + 1]['start'] - months[k]['start']) / 86400000)
            assert length in (29, 30)
            if length == 30:
                lens |= 1 << (k - a)
            if months[k]['month'].startswith('闰'):
                leap = int(months[k]['month'][1:])
        doy = ny.timetuple().tm_yday
        assert 21 <= doy <= 51, ny
        words.append(lens | leap << 13 | (doy - 21) << 17)
    return words, CAL_FIRST - 1


# ---------------------------------------------------------------- outputs

def monkey_array(values):
    return '[' + ','.join(str(v) for v in values) + ']'


def write_generated(term_words, lunar_words, lunar_first, metrics):
    s = SCENE
    fm = []
    for name, f in metrics.items():
        cap = f['glyphs']['步'][3] - 2 if '步' in f['glyphs'] else f['glyphs']['0'][3] - 2
        fm.append(f'    const {name.upper()}_BASE = {f["base"]};')
        fm.append(f'    const {name.upper()}_CAP = {cap};')
    lines = [
        '// Generated by generate_assets.py. Do not edit; change the generator instead.',
        '// font ascent (baseline below the drawText y) and glyph height, per bitmap font',
        'module Fm {',
    ] + fm + [
        '}',
        '',
        'module Geo {',
        f'    const HORIZON = {s["horizon"]};',
        '    // landscape polygons in paint order; ROLES[i] picks the palette colour (see Scene.mc)',
        '    const ROLES = [' + ','.join(str(ROLE_IDS.index(r)) for r, _ in s['shapes']) + '];',
        '    const SHAPES = [' + ','.join(monkey_array(flat(p)) for _, p in s['shapes']) + '];',
        f'    const CABIN = {monkey_array(flat(s["cabin"]))};',
        f'    const WINDOW = {monkey_array(flat(s["window"]))};',
        f'    const CHIMNEY = {monkey_array(flat(s["chimney"]))};',
        f'    const DOOR = {monkey_array(flat(s["door"]))};',
        f'    const SMOKE = {monkey_array(s["smoke"])};',
        f'    const FAR_RIDGE = {monkey_array(flat(s["farRidge"]))};',
        f'    const LAVA = {monkey_array(flat(s["lava"]))};',
        f'    const BOLT = {monkey_array(flat(s["bolt"]))};',
        f'    const APEX = {monkey_array(s["apex"])};',
        f'    const RIDGE = {monkey_array(flat(s["ridge"]))};',
        f'    const SKYLINE = {monkey_array(s["skyline"])};',
        '}',
        '',
        'module CalData {',
        f'    const TERM_FIRST = {CAL_FIRST};',
        f'    const TERMS = {monkey_array(term_words)};',
        f'    const LUNAR_FIRST = {lunar_first};',
        f'    const LUNAR = {monkey_array(lunar_words)};',
        '}',
    ]
    (ROOT / 'source/Generated.mc').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def launcher_icon():
    s = 4 * 60 / 454
    img = Image.new('RGB', (240, 240), 'black')
    d = ImageDraw.Draw(img)
    for y in range(int(HORIZON * s)):
        k = y / (HORIZON * s)
        d.line([(0, y), (240, y)], fill=tuple(int(a + (b - a) * k) for a, b in zip((24, 32, 72), (214, 150, 120))))
    colors = {'far': '#7d7493', 'range': '#4f4a6a', 'body': '#1c1a2b', 'snowL': '#ffd7a0', 'snowR': '#a99cc0',
              'streakL': '#f2c99a', 'streakR': '#7d7296', 'hills': '#262338', 'ground': '#121120', 'tree': '#0a0912',
              'treeFar': '#1a1828'}
    for role, pts in SHAPES:
        d.polygon([(x * s, y * s) for x, y in pts], fill=colors[role])
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, 239, 239], fill=255)
    out = Image.new('RGB', img.size, 'black')
    out.paste(img, (0, 0), mask)
    out.resize((60, 60), Image.LANCZOS).save(ROOT / 'resources/drawables/icon.png')


def main():
    metrics = fonts()
    term_words, term_table = solar_terms()
    lunar_words, lunar_first = lunar_years()
    write_generated(term_words, lunar_words, lunar_first, metrics)
    launcher_icon()
    data = {'scene': SCENE, 'fonts': metrics, 'cal': {'termFirst': CAL_FIRST, 'terms': term_words,
                                                       'lunarFirst': lunar_first, 'lunar': lunar_words}}
    (ROOT / 'preview-data.json').write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')),
                                            encoding='utf-8')
    print(f'fonts: {", ".join(metrics)}; CJK glyphs: {len(CJK)}')
    print(f'solar terms {CAL_FIRST}-{CAL_LAST}; lunar years {lunar_first}-{lunar_first + len(lunar_words) - 1}')
    print('2026 terms:', ' '.join(f'{TERM_NAMES[i]}{term_table[2026][i]}' for i in range(24)))


if __name__ == '__main__':
    main()
