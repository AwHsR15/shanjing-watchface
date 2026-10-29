"""Connect IQ toolchain paths shared by build.py, test_native.py and capture_sim.py."""
from pathlib import Path
import os

ROOT = Path(__file__).resolve().parent
# Defaults are this machine's layout; set CIQ_SDK (the SDK folder that holds bin/), CIQ_KEY (your
# developer key, never committed) and CIQ_JAVA to build elsewhere.
TOOLS = ROOT.parent / 'watchface-install'
SDK_BIN = Path(os.environ['CIQ_SDK']) / 'bin' if os.environ.get('CIQ_SDK') else TOOLS / 'sdk' / 'bin'
KEY = Path(os.environ.get('CIQ_KEY') or TOOLS / 'developer_key.der')
JAVA = os.environ.get('CIQ_JAVA') or 'C:/Program Files/Java/jdk-17/bin/java.exe'
DEVICE = 'epix2pro51mm'

# The SDK Manager was started from the Codex desktop app (an MSIX package), so its
# %APPDATA% writes landed in the package's virtualised Roaming folder, not the real one.
_CANDIDATES = [
    Path(os.environ.get('APPDATA', '')),
    Path.home() / 'AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Roaming',
]


def appdata():
    for p in _CANDIDATES:
        if (p / 'Garmin/ConnectIQ/Devices' / DEVICE / 'compiler.json').exists():
            return p
    raise SystemExit('Garmin device files for %s not found; download them with the SDK Manager.' % DEVICE)


def env():
    e = dict(os.environ)
    e['APPDATA'] = str(appdata())
    e['TMP'] = e['TEMP'] = str(ROOT / 'build' / 'tmp')
    return e


def java(*args):
    # keep the compiler's scratch files on D: (the system drive can run out of space)
    tmp = ROOT / 'build' / 'tmp'
    tmp.mkdir(parents=True, exist_ok=True)
    return [JAVA, '-Dfile.encoding=UTF-8', '-Xmx1g', f'-Djava.io.tmpdir={tmp}', '-cp', str(SDK_BIN / 'monkeybrains.jar'), *args]


def compile_args(output, test=False):
    return java('com.garmin.monkeybrains.Monkeybrains', '-d', DEVICE, '-f', 'monkey.jungle', '-o', str(output),
                '-y', str(KEY), '-t' if test else '-r', '-w')
