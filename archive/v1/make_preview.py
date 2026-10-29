"""Bundle the preview so it also opens by double-click without a local server."""
from pathlib import Path
import base64,json
root=Path(__file__).resolve().parent
page=(root/'preview.html').read_text(encoding='utf-8')
js=(root/'preview-render.js').read_text(encoding='utf-8')
old="await Promise.all(['landscape.json','font-metrics.json'].map(p=>fetch(p).then(r=>r.json())))"
assert old in js
js=js.replace(old,json.dumps([json.loads((root/'landscape.json').read_text()),json.loads((root/'font-metrics.json').read_text())]))
assets={n:'data:image/png;base64,'+base64.b64encode((root/f'resources/fonts/{n}.png').read_bytes()).decode() for n in ['TimeFont','SmallFont','MediumFont']}
js='const embeddedFonts='+json.dumps(assets)+';\n'+js.replace('`resources/fonts/${name}.png`','embeddedFonts[name]')
page=page.replace('<script src="preview-render.js"></script>','<script>'+js+'</script>')
(root/'山境-打开预览.html').write_text(page,encoding='utf-8')
print('Standalone preview written.')
