from pathlib import Path
import subprocess, json, hashlib
root=Path(__file__).resolve().parent
tools=root.parent/'watchface-install'
args=['C:/Program Files/Java/jdk-17/bin/java.exe','-Dfile.encoding=UTF-8','-Xmx1g','-cp',str(tools/'sdk/bin/monkeybrains.jar'),'com.garmin.monkeybrains.Monkeybrains','-d','epix2pro51mm','-f','monkey.jungle','-o',str(root/'build/Mountain.prg'),'-y',str(tools/'developer_key.der'),'-r']
p=subprocess.run(args,cwd=root,capture_output=True)
log=p.stdout.decode('utf-8',errors='replace')+p.stderr.decode('utf-8',errors='replace')
(root/'build/compiler.log').write_text(log,encoding='utf-8');print(log)
if p.returncode==0:
    f=root/'build/Mountain.prg'
    report={'target':'epix2pro51mm','compiled':True,'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'simulator_visual_verified':False,'watch_verified':False}
    (root/'build/result.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report))
raise SystemExit(p.returncode)
