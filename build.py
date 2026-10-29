"""Release build of 山境 for EPIX Pro 51mm -> build/Mountain.prg; `python build.py diag` -> build/diag/Mountain.prg with frame timings logged"""
import hashlib, json, subprocess, sys
import ciq

diag = 'diag' in sys.argv[1:]
out = ciq.ROOT / ('build/diag/Mountain.prg' if diag else 'build/Mountain.prg')
out.parent.mkdir(parents=True, exist_ok=True)
args = ciq.compile_args(out)
if diag: args[args.index('monkey.jungle')] = 'diag.jungle'
p = subprocess.run(args, cwd=ciq.ROOT, capture_output=True, env=ciq.env())
log = p.stdout.decode('utf-8', errors='replace') + p.stderr.decode('utf-8', errors='replace')
(ciq.ROOT / 'build/compiler.log').write_text(log, encoding='utf-8')
print(log)
if p.returncode == 0 and not diag:
    report = {'target': ciq.DEVICE, 'compiled': True, 'bytes': out.stat().st_size,
              'sha256': hashlib.sha256(out.read_bytes()).hexdigest()}
    (ciq.ROOT / 'build/result.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))
raise SystemExit(p.returncode)
