# gym screenshot: start client (minimized), build the gym, raise the camera, ask the engine for screenshots
import time, pathlib, subprocess, os, glob
R = pathlib.Path("C:/re/abioticfactor")
M = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\AbioticFactor\AbioticFactor\Binaries\Win64\ue4ss\Mods\mods.txt")
M.write_text(M.read_text().replace("AfPilot : 0", "AfPilot : 1"))
def pc(c, w): (R / "pilot_cmd.txt").write_text(c + "\n"); time.sleep(w)
subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(R / "run_route.ps1"), "bandage", "1"])
pc("tpabs -17709 13563 208", 4); pc("gym 1200", 6)
(R / "faircrew_cmd.txt").write_text("bot 300\n"); time.sleep(8)
pc("exec HighResShot 1920x1080", 6)
pc("tpabs -18709 12563 208", 4); pc("exec HighResShot 1920x1080", 6)
pc("exec Shot", 5)
print((R / "pilot_out.txt").read_text(errors="replace")[-600:])
for d in (os.path.expandvars(r"%LOCALAPPDATA%\AbioticFactor\Saved"), r"C:\Program Files (x86)\Steam\steamapps\common\AbioticFactor\AbioticFactor\Saved"):
    for f in glob.glob(d + r"\**\*.png", recursive=True) + glob.glob(d + r"\**\*.bmp", recursive=True):
        if time.time() - os.path.getmtime(f) < 600: print("SHOT", f)
