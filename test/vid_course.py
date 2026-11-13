# video: crew member on the parkour course; HighResShot frames -> shots/vid/
import time, pathlib, subprocess, os, glob, shutil, sys
R = pathlib.Path("C:/re/abioticfactor")
M = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\AbioticFactor\AbioticFactor\Binaries\Win64\ue4ss\Mods\mods.txt")
SD = pathlib.Path(os.path.expandvars(r"%LOCALAPPDATA%\AbioticFactor\Saved\Screenshots\Windows"))
OUT = R / "shots" / "vid"; shutil.rmtree(OUT, ignore_errors=True); OUT.mkdir(parents=True)
for f in SD.glob("HighresScreenshot*.png"): f.unlink()
M.write_text(M.read_text().replace("AfPilot : 0", "AfPilot : 1"))
LOG = R / "faircrew_log.txt"
def pc(c, w=1.0): (R / "pilot_cmd.txt").write_text(c + "\n"); time.sleep(w)
def fc(c, w=1.0): (R / "faircrew_cmd.txt").write_text(c + "\n"); time.sleep(w)
def alive(): return "AbioticFactor-Win64" in subprocess.run(["tasklist"], capture_output=True, text=True).stdout
n0 = len(LOG.read_text(errors="replace").splitlines())
subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(R / "run_route.ps1"), "bandage", "1"])
pc("tpabs -17709 13563 208", 4); pc("gym 1200", 6)
fc("bot 300", 8)
t0 = time.time()
while time.time() - t0 < 40 and "recruited Crew" not in chr(10).join(LOG.read_text(errors="replace").splitlines()[n0:]): time.sleep(1.5)
pc("tpabs -17709 13563 208", 4); fc("body 300", 4); fc("bodyctl", 3); fc("parkour", 4); fc("bodytp 180 -250", 2); fc("mvwho crew", 1.5); fc("bodytp 0 0", 2); fc("pkcam -150 -260", 2); fc("mvspd 500 28", 1.5)
if not alive(): sys.exit("client died")
# crew member: lane (hurdle, bar), then ladder to the platform
TL = {2: "mvauto 0 700", 22: "bodytp -150 900", 23: "pkcam -170 640", 26: "mvup"}
for t in range(40):
    if t in TL: fc(TL[t], 1.0)
    pc("exec HighResShot 1280x720", 1.0)
time.sleep(3)
fs = sorted(SD.glob("HighresScreenshot*.png"))
for i, f in enumerate(fs): shutil.copy(f, OUT / f"f{i:04d}.png")
print("frames", len(fs), "alive", alive())
print("\n".join(LOG.read_text(errors="replace").splitlines()[n0:][-70:]))
