"""Generate original polygon artwork and bitmap fonts; no reference assets copied."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json

ROOT=Path(__file__).resolve().parent
SHAPES=[
 ('#46636b',[[22,225],[73,166],[101,187],[153,134],[204,194],[265,151],[316,185],[361,153],[432,223],[432,246],[22,246]]),
 ('#2b464f',[[30,244],[100,192],[130,209],[185,157],[235,202],[284,164],[336,213],[378,189],[425,229],[425,251],[30,251]]),
 ('#152a34',[[77,251],[150,188],[180,195],[244,104],[272,139],[288,132],[375,247]]),
 ('#e3e9dc',[[169,211],[244,104],[259,125],[243,119],[221,156],[226,133],[207,163],[208,147],[188,183],[190,169]]),
 ('#8ba8ad',[[244,104],[272,139],[288,132],[302,154],[289,147],[293,166],[272,151],[256,173],[265,149],[246,163],[254,140],[235,160],[245,130],[227,151]]),
 ('#ceded6',[[212,176],[229,157],[218,179],[215,197],[200,218],[204,196],[189,212]]),
 ('#557982',[[266,166],[280,157],[297,182],[286,176],[294,194],[278,184],[261,210],[274,183]]),
 ('#203a43',[[37,251],[92,222],[129,230],[167,211],[203,238],[245,218],[281,235],[330,208],[367,220],[421,211],[429,259],[26,259]]),
 ('#0d1d25',[[16,249],[65,235],[102,245],[154,235],[190,252],[244,242],[298,250],[353,233],[409,245],[438,239],[438,266],[16,266]])
]
for x,y,h in [(48,244,22),(69,244,32),(87,250,20),(361,248,23),(383,248,35),(402,250,26)]:
    SHAPES.append(('#071217',[[x,y-h],[x-4,y-h+10],[x-2,y-h+10],[x-8,y-4],[x-3,y-4],[x-3,y+4],[x+3,y+4],[x+3,y-4],[x+8,y-4],[x+2,y-h+10],[x+4,y-h+10]]))
def fonts():
    defs=[]; metrics={}
    for name,size in [('TimeFont',82),('MediumFont',28),('SmallFont',17)]:
        chars='0123456789:' if name=='TimeFont' else ''.join(chr(i) for i in range(32,127))
        font=ImageFont.truetype('C:/Windows/Fonts/impact.ttf' if name=='TimeFont' else 'C:/Windows/Fonts/bahnschrift.ttf',size)
        height=size+7; cell=size+8; cols=16; rows=(len(chars)+cols-1)//cols
        img=Image.new('RGBA',(cols*cell,rows*height),(0,0,0,0)); draw=ImageDraw.Draw(img)
        lines=[f'info face="{name}" size={size}',f'common lineHeight={height} base={size} scaleW={img.width} scaleH={img.height} pages=1 packed=0',f'page id=0 file="{name}.png"',f'chars count={len(chars)}']
        data={}
        for i,ch in enumerate(chars):
            x=i%cols*cell;y=i//cols*height; w=int(font.getlength(ch))+1
            draw.text((x,y),ch,font=font,fill='white',anchor='lt')
            lines.append(f'char id={ord(ch)} x={x} y={y} width={w} height={height} xoffset=0 yoffset=0 xadvance={w} page=0 chnl=15')
            data[ch]=[x,y,w,height]
        img.save(ROOT/f'resources/fonts/{name}.png')
        (ROOT/f'resources/fonts/{name}.fnt').write_text('\n'.join(lines))
        defs.append(f'<font id="{name}" filename="{name}.fnt"/>');metrics[name]=data
    (ROOT/'resources/fonts/fonts.xml').write_text('<fonts>'+''.join(defs)+'</fonts>')
    (ROOT/'font-metrics.json').write_text(json.dumps(metrics))

fonts()
mc=['using Toybox.Graphics;', 'function drawMountain(dc, volcano, dusk) {']
for color,points in SHAPES:
    paint='dusk ? 0xE6BD8D : 0x'+color[1:] if color=='#e3e9dc' else '0x'+color[1:]
    mc.append(f'    dc.setColor({paint}, Graphics.COLOR_TRANSPARENT); dc.fillPolygon({json.dumps(points)});')
mc += ['    if(volcano) {','        dc.setColor(0xE88355, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[242,112],[249,119],[241,143],[250,163],[239,188],[243,165],[234,146]]);','    }','}']
(ROOT/'source/Landscape.mc').write_text('\n'.join(mc))
(ROOT/'landscape.json').write_text(json.dumps(SHAPES))
im=Image.new('RGBA',(60,60),'black');d=ImageDraw.Draw(im)
d.polygon([(8,43),(29,13),(51,43)],fill='#edf5ed');d.polygon([(29,19),(32,30),(26,26),(19,38)],fill='#285b6b')
im.save(ROOT/'resources/drawables/icon.png')
(ROOT/'resources/drawables/drawables.xml').write_text('<drawables><bitmap id="LauncherIcon" filename="icon.png"/></drawables>')
print('Generated fonts, shared mountain geometry, launcher icon.')
