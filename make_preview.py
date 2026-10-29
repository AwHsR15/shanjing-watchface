"""Bundle preview.html + preview-render.js + data + font atlases into one file that opens by double-click."""
from pathlib import Path
import base64, json

root = Path(__file__).resolve().parent
page = (root / 'preview.html').read_text(encoding='utf-8')
js = (root / 'preview-render.js').read_text(encoding='utf-8')
data = json.loads((root / 'preview-data.json').read_text(encoding='utf-8'))
fonts = {n: 'data:image/png;base64,' + base64.b64encode((root / f'resources/fonts/{n}.png').read_bytes()).decode()
         for n in data['fonts']}
embedded = ('window.EMBEDDED_DATA=' + json.dumps(data, ensure_ascii=False, separators=(',', ':')) + ';\n'
            'window.EMBEDDED_FONTS=' + json.dumps(fonts) + ';\n')
page = page.replace('<script src="preview-render.js"></script>', '<script>' + embedded + js + '</script>')
(root / '山境-打开预览.html').write_text(page, encoding='utf-8')
print('Standalone preview written:', root / '山境-打开预览.html')
