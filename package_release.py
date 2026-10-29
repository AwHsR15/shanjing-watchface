"""Zip the release PRG, sources, previews and notes into build/Mountain-EpixPro51.zip (no signing key)."""
from pathlib import Path
import hashlib, json, zipfile

root = Path(__file__).resolve().parent
log = (root / 'build/native-test.log').read_text(encoding='utf-8', errors='replace')
assert 'PASSED (passed=1, failed=0, errors=0)' in log, 'run test_native.py first'
files = [p for p in root.iterdir() if p.is_file() and p.suffix in ('.md', '.py', '.html', '.js', '.json', '.xml', '.jungle')]
files += [p for d in ('source', 'resources', '预览图') for p in (root / d).rglob('*') if p.is_file()]
files += [root / 'build' / n for n in ('Mountain.prg', 'result.json', 'native-test.log', 'compiler.log')]
out = root / 'build/Mountain-EpixPro51.zip'
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for p in files:
        z.write(p, 'Mountain/' + p.relative_to(root).as_posix())
with zipfile.ZipFile(out) as z:
    assert z.testzip() is None
    assert not any(n.endswith('.der') for n in z.namelist())
print(json.dumps({'package': str(out), 'files': len(files), 'bytes': out.stat().st_size,
                  'sha256': hashlib.sha256(out.read_bytes()).hexdigest()}, ensure_ascii=False))
