from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parent
log=(root/'build/native-test.log').read_text(encoding='utf-8')
assert 'PASSED (passed=1, failed=0, errors=0)' in log, 'Native render test must pass before packaging'
result=json.loads((root/'build/result.json').read_text())
result.pop('simulator_verified',None)
result.update(simulator_visual_verified=False,simulator_render_test_passed=True,browser_visual_review=True)
result['native_source_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'source').glob('*.mc')}
(root/'build/result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
files=[p for p in root.iterdir() if p.is_file()]
files += list((root/'source').glob('*'))+list((root/'resources').rglob('*'))
files += [root/'build'/name for name in ['Mountain.prg','result.json','native-test.log','compiler.log','three-scenes.png']]
out=root/'build/Mountain-EpixPro51.zip'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
    for p in files:
        if p.is_file():z.write(p,'Mountain/'+p.relative_to(root).as_posix())
with zipfile.ZipFile(out) as z:
    assert z.testzip() is None
    assert not any('developer_key' in n or n.endswith('.der') for n in z.namelist())
print(json.dumps({'package':str(out),'bytes':out.stat().st_size,'file_count':len(files),'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}))
