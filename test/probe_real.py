# 11-13 real-item probes: one engine call per step, client liveness after each. Usage: py -3.13 -I probe_real.py
import time, pathlib, subprocess, sys
R = pathlib.Path("C:/re/abioticfactor")
def alive(): return b"AbioticFactor-Win64" in subprocess.run(["tasklist"], capture_output=True).stdout
def fc(c, w):
    (R / "faircrew_cmd.txt").write_text(c + "\n"); time.sleep(w)
    if not alive():
        print("CLIENT DEAD after:", c); print("crumb:", (R / "faircrew_crumb.txt").read_text(errors="replace")[-300:]); tail(); sys.exit(1)
def tail():
    for l in (R / "faircrew_log.txt").read_text(errors="replace").splitlines():
        if any(k in l for k in ("boxslots", "ownslots", "slotv", "putv", "invsize", "ownput", "boxw", "ownw", "boxput", "owntake", "thing", "cmd error", "moved in", "porter")): print(l)
subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(R / "run_route.ps1"), "bandage", "6"])
(R / "pilot_cmd.txt").write_text("tpabs -17709 13563 208\n"); time.sleep(4)
(R / "pilot_cmd.txt").write_text("gym 1200\n"); time.sleep(4)
fc("bot 300", 12); fc("botfar 1500", 15); fc("botbed 120", 8); time.sleep(40)
fc("box 300", 4)
for c in sys.argv[1:] or ["ownw", "boxw", "boxput bandage 2", "boxw", "owntake bandage 1", "ownw", "owntakehot bandage 1", "ownw", "boxput bandage 1", "boxw"]:
    fc(c.replace("_", " "), 5)
print("client alive:", alive()); tail()
