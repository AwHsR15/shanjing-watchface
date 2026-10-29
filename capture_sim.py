"""Run the demo build in the Connect IQ simulator and capture its screen as PNGs (build/sim/).

The demo build cycles through preset scenes every 5 s (source/Demo.mc). Frames are grabbed from the
simulator window with PrintWindow, so the window may sit behind others but must not be minimised.
"""
import ctypes, ctypes.wintypes as wt, subprocess, sys, time
from pathlib import Path
from PIL import Image
import ciq

OUT = ciq.ROOT / 'build/sim'
user32, gdi32 = ctypes.windll.user32, ctypes.windll.gdi32
user32.SetProcessDPIAware()


def simulator_hwnd():
    result = []
    pids = set()
    out = subprocess.run(['tasklist', '/FI', 'IMAGENAME eq simulator.exe', '/FO', 'CSV', '/NH'], capture_output=True, text=True).stdout
    for line in out.splitlines():
        parts = line.strip('"').split('","')
        if len(parts) > 1 and parts[1].isdigit():
            pids.add(int(parts[1]))

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def cb(hwnd, _):
        pid = wt.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        if pid.value in pids and user32.IsWindowVisible(hwnd):
            title = ctypes.create_unicode_buffer(200); user32.GetWindowTextW(hwnd, title, 200)
            if 'Error' in title.value:  # a leftover error dialog would otherwise be the biggest window
                user32.PostMessageW(hwnd, 0x0010, 0, 0)  # WM_CLOSE
                return True
            if user32.IsIconic(hwnd):
                user32.ShowWindow(hwnd, 9)  # SW_RESTORE: a minimised window reports a tiny size and grabs blank
                time.sleep(1)
            r = wt.RECT(); user32.GetWindowRect(hwnd, ctypes.byref(r))
            if r.right - r.left > 300:
                result.append(((r.right - r.left) * (r.bottom - r.top), hwnd))
        return True
    user32.EnumWindows(cb, 0)
    return max(result)[1] if result else None  # the main window is the largest one


def grab(hwnd):
    r = wt.RECT(); user32.GetWindowRect(hwnd, ctypes.byref(r))
    w, h = r.right - r.left, r.bottom - r.top
    hdc = user32.GetWindowDC(hwnd); mem = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h); gdi32.SelectObject(mem, bmp)
    user32.PrintWindow(hwnd, mem, 2)
    buf = ctypes.create_string_buffer(w * h * 4)
    bi = (ctypes.c_uint32 * 10)(40, w, -h, 1 | (32 << 16), 0, 0, 0, 0, 0, 0)
    gdi32.GetDIBits(mem, bmp, 0, h, buf, ctypes.byref(bi), 0)
    gdi32.DeleteObject(bmp); gdi32.DeleteDC(mem); user32.ReleaseDC(hwnd, hdc)
    return Image.frombuffer('RGBA', (w, h), buf, 'raw', 'BGRA', 0, 1).convert('RGB')


def main():
    seconds = float(sys.argv[1]) if len(sys.argv) > 1 else 50
    prg = ciq.ROOT / 'build/Mountain-demo.prg'
    args = ciq.compile_args(prg)
    args[args.index('monkey.jungle')] = 'demo.jungle'
    subprocess.run(args, cwd=ciq.ROOT, check=True, env=ciq.env())
    hwnd = simulator_hwnd()
    if hwnd is None:
        subprocess.Popen([str(ciq.SDK_BIN / 'simulator.exe')], cwd=ciq.SDK_BIN, env=ciq.env())  # temp on D:
        for _ in range(40):
            time.sleep(0.5)
            hwnd = simulator_hwnd()
            if hwnd: break
    if user32.IsIconic(hwnd):
        user32.ShowWindow(hwnd, 9)  # SW_RESTORE: PrintWindow returns blank frames for a minimised window
        time.sleep(1)
    run = ciq.java('com.garmin.monkeybrains.monkeydodeux.MonkeyDoDeux', '-f', str(prg), '-d', ciq.DEVICE, '-s', str(ciq.SDK_BIN / 'shell.exe'))
    log = open(ciq.ROOT / 'build/sim-console.log', 'wb', buffering=0)
    proc = subprocess.Popen(run, cwd=ciq.ROOT, stdout=log, stderr=subprocess.STDOUT, env=ciq.env())
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob('frame-*.png'): old.unlink()
    # the demo build prints "preset i" when it switches; note which preset each frame belongs to
    start = time.time(); n = 0; index = []
    while time.time() - start < seconds:
        grab(hwnd).save(OUT / f'frame-{n:03d}.png')
        lines = [l for l in (ciq.ROOT / 'build/sim-console.log').read_text(errors='replace').splitlines() if l.startswith('preset ')]
        index.append(lines[-1][7:] if lines else '')
        n += 1
        time.sleep(0.25)
    (OUT / 'frames.txt').write_text(chr(10).join(index), encoding='utf-8')
    print(f'captured {n} frames into {OUT}')
    proc.terminate()


if __name__ == '__main__':
    main()
