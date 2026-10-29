"""Build with unit tests and run RenderTest.mc in the Connect IQ simulator (start sdk/bin/simulator.exe first)."""
import subprocess
import ciq

out = ciq.ROOT / 'build/Mountain-test.prg'
p = subprocess.run(ciq.compile_args(out, test=True), cwd=ciq.ROOT, capture_output=True, env=ciq.env())
log = p.stdout + p.stderr
if p.returncode == 0:
    run = ciq.java('com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux', '-f', str(out), '-d', ciq.DEVICE,
                   '-s', str(ciq.SDK_BIN / 'shell.exe'), '-t')
    try:
        p = subprocess.run(run, cwd=ciq.ROOT, capture_output=True, timeout=120, env=ciq.env())
        log += p.stdout + p.stderr
    except subprocess.TimeoutExpired as e:
        log += (e.stdout or b'') + (e.stderr or b'') + b'\nTEST TIMEOUT\n'
(ciq.ROOT / 'build/native-test.log').write_bytes(log)
print(log.decode('utf-8', errors='replace'))
# MonkeyDoDeux can exit 1 after a clean simulator shutdown; trust the runner's own summary line.
raise SystemExit(0 if b'PASSED (passed=1, failed=0, errors=0)' in log else 1)
