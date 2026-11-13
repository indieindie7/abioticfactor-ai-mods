# video: bot owner + crew scientist near the gym centre; HighResShot frames -> shots/vid/
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
if "cont" not in sys.argv:
    subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(R / "run_route.ps1"), "bandage", "1"])
    pc("tpabs -17709 13563 208", 4); pc("gym 1200", 6)
    fc("bot 300", 8); fc("ownbot", 2); fc("cam", 3)
fc("cam", 2)
print("alive after look:", alive(), flush=True)
if not alive(): sys.exit("client died on look")
# timeline: second -> faircrew command
fc("botplace -17750 13900", 1.5); fc("crewtobot", 1.5); fc("cam", 2)
TL = {5: "botgo -150 150", 25: "botgo 100 -200", 45: "botbed 120", 49: "crewtobot", 58: "needs 5 100", 62: "botgo -150 150", 95: "status"}
for t in range(105):
    if t in TL: fc(TL[t], 0.7)
    elif t % 2 == 0: fc("cam", 0.4)
    pc("exec HighResShot 1280x720", 1.0)
time.sleep(3)
fs = sorted(SD.glob("HighresScreenshot*.png"))
for i, f in enumerate(fs): shutil.copy(f, OUT / f"f{i:04d}.png")
print("frames", len(fs), "alive", alive())
print("\n".join(LOG.read_text(errors="replace").splitlines()[n0:][-70:]))
