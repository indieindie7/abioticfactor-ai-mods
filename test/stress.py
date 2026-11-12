# crash hunt: hammer the bot walker until the client dies, then print breadcrumb + log tail
import time, pathlib, subprocess, random, sys
R = pathlib.Path("C:/re/abioticfactor")
def alive(): return b"AbioticFactor-Win64" in subprocess.run(["tasklist"], capture_output=True).stdout
def fc(c, w): (R / "faircrew_cmd.txt").write_text(c + "\n"); time.sleep(w)
(R / "pilot_cmd.txt").write_text("tpabs -17709 13563 208\n"); time.sleep(4)
(R / "pilot_cmd.txt").write_text("gym 1200\n"); time.sleep(4)
fc("bot 300", 12); fc("botfar 1500", 15); fc("botbed 120", 8)
mins = float(sys.argv[1]) if len(sys.argv) > 1 else 20
JOBS = len(sys.argv) > 2 and sys.argv[2] == "jobs"   # also hammer the Porter + Guard commands
if JOBS: fc("box 300", 3)
t0 = time.time(); n = 0
while time.time() - t0 < mins * 60 and alive():
    pool = ["botfar 4000", "botback", "botfar 4500", "botfar 1500", "botcrew"]
    if JOBS: pool += ["job porter", "job guard", "job none", "bothold Scrap 2", "enemy 1000", "enemykill", "needs 100 100", "needs 10 100", "boxes"]
    fc(random.choice(pool), random.choice([4, 8, 14])); n += 1
print("alive" if alive() else "DEAD", "cmds", n, "min %.1f" % ((time.time() - t0) / 60))
cr = R / "faircrew_crumb.txt"; print("crumb:", cr.read_text() if cr.exists() else "none")
print("\n".join((R / "faircrew_log.txt").read_text(errors="replace").splitlines()[-8:]))
