# Movement probe (11-13): spare player-pipeline body (FairCrew `body`), 0.1 s sampler, one "mv ..." summary per action.
# Usage: py -3.13 -I mod/test/move_probe.py "cmd:wait" "cmd:wait" ...   (default list below). Leaves mods.txt AfPilot 0, kills client.
import time, pathlib, subprocess, sys
R = pathlib.Path("C:/re/abioticfactor")
M = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\AbioticFactor\AbioticFactor\Binaries\Win64\ue4ss\Mods\mods.txt")
def alive(): return b"AbioticFactor-Win64" in subprocess.run(["tasklist"], capture_output=True).stdout
def fc(c, w): (R / "faircrew_cmd.txt").write_text(c + "\n"); time.sleep(w)
def pc(c, w): (R / "pilot_cmd.txt").write_text(c + "\n"); time.sleep(w)
steps = sys.argv[1:] or ["mvgo 0 600:10", "mvgo 0 -600:10", "mvjump:4", "mvcrouch 1:3", "mvgo 0 300:10", "mvcrouch 0:3",
                         "mvcall ToggleSprint:4", "mvgo 0 -900:10", "mvcall ToggleSprint:4", "mvcall ToggleCrouch:4", "mvcall ToggleCrouch:4"]
M.write_text(M.read_text().replace("AfPilot : 0", "AfPilot : 1"))
subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(R / "run_route.ps1"), "bandage", "1"])
pc("tpabs -17709 13563 208", 4); pc("gym 1200", 6)
fc("body 300", 4); fc("bodyctl", 3)
for s in steps:
    c, w = s.rsplit(":", 1)
    if not alive(): print("CLIENT DIED before", c); break
    fc(c, float(w))
print("alive at end:", alive())
subprocess.run(["taskkill", "/F", "/IM", "AbioticFactor-Win64-Shipping.exe"], capture_output=True)
M.write_text(M.read_text().replace("AfPilot : 1", "AfPilot : 0"))
for l in (R / "faircrew_log.txt").read_text(errors="replace").splitlines():
    if any(k in l for k in (" mv", "body", " mo ", " lad", "parkour", "rror", "ERR")): print(l[:260])
print("crumb:", (R / "faircrew_crumb.txt").read_text(errors="replace")[:80])
