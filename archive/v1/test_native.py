from pathlib import Path
import subprocess
root=Path(__file__).resolve().parent
sdk=root.parent/'watchface-install'
java='C:/Program Files/Java/jdk-17/bin/java.exe'
base=[java,'-Dfile.encoding=UTF-8','-cp',str(sdk/'sdk/bin/monkeybrains.jar')]
compile=base+['com.garmin.monkeybrains.Monkeybrains','-d','epix2pro51mm','-f','monkey.jungle','-o',str(root/'build/Mountain-test.prg'),'-y',str(sdk/'developer_key.der'),'-t']
p=subprocess.run(compile,cwd=root,capture_output=True)
log=p.stdout+p.stderr
if p.returncode==0:
    run=base+['com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux','-f',str(root/'build/Mountain-test.prg'),'-d','epix2pro51mm','-s',str(sdk/'sdk/bin/shell.exe'),'-t']
    try:
        p=subprocess.run(run,cwd=root,capture_output=True,timeout=75)
        log+=p.stdout+p.stderr
    except subprocess.TimeoutExpired as e:
        log+=(e.stdout or b'')+(e.stderr or b'')+b'\nTEST TIMEOUT\n'
        (root/'build/native-test.log').write_bytes(log)
        print(log.decode('utf-8',errors='replace'));raise SystemExit(1)
(root/'build/native-test.log').write_bytes(log)
print(log.decode('utf-8',errors='replace'))
# MonkeyDoDeux may return 1 after a successful simulator shutdown; require the
# test runner's explicit result instead of interpreting that alone as failure.
passed=b'PASSED (passed=1, failed=0, errors=0)' in log
raise SystemExit(0 if passed else 1)
