# probe: player-pipeline body as an NPC (spawn, render, default controller)
import time, pathlib, subprocess, os, shutil
R = pathlib.Path("C:/re/abioticfactor")
M = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\AbioticFactor\AbioticFactor\Binaries\Win64\ue4ss\Mods\mods.txt")
SD = pathlib.Path(os.path.expandvars(r"%LOCALAPPDATA%\AbioticFactor\Saved\Screenshots\Windows"))
for f in SD.glob("HighresScreenshot*.png"): f.unlink()
M.write_text(M.read_text().replace("AfPilot : 0", "AfPilot : 1"))
def pc(c, w=1.0): (R / "pilot_cmd.txt").write_text(c + "\n"); time.sleep(w)
def fc(c, w=1.0): (R / "faircrew_cmd.txt").write_text(c + "\n"); time.sleep(w)
def alive(): return "AbioticFactor-Win64" in subprocess.run(["tasklist"], capture_output=True, text=True).stdout
subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(R / "run_route.ps1"), "bandage", "1"])
pc("tpabs -17709 13563 208", 4)
fc("body 300", 5); print("alive after body:", alive(), flush=True)
pc("exec HighResShot 1280x720", 4)
if alive(): fc("bodyctl", 5); print("alive after bodyctl:", alive(), flush=True)
if alive(): fc("bodypos", 2); pc("exec HighResShot 1280x720", 3)
if alive(): fc("bodyrows", 5); print("alive after bodyrows:", alive(), flush=True)
if alive(): fc("bodyclone", 4); print("alive after bodyclone:", alive(), flush=True); pc("exec HighResShot 1280x720", 3)
for k in range(3):
    if not alive(): break
    fc("bodylook", 4); print("alive after bodylook:", alive(), flush=True); pc("exec HighResShot 1280x720", 3)
for i, f in enumerate(sorted(SD.glob("HighresScreenshot*.png"))): shutil.copy(f, R / "shots" / f"body{i}.png"); print("shot", i)
print("alive end:", alive())
