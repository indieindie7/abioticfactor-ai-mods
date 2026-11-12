# Porter + Guard bot-owner test (client gym). Prints the job lines of faircrew_log.txt at the end.
import time, pathlib, subprocess
R = pathlib.Path("C:/re/abioticfactor")
def alive(): return b"AbioticFactor-Win64" in subprocess.run(["tasklist"], capture_output=True).stdout
def fc(c, w):
    (R / "faircrew_cmd.txt").write_text(c + "\n"); time.sleep(w)
def log(): return (R / "faircrew_log.txt").read_text(errors="replace")
def wait(s, t):
    t0 = time.time()
    while time.time() - t0 < t and alive():
        if s in log(): return True
        time.sleep(2)
    return False
(R / "pilot_cmd.txt").write_text("tpabs -17709 13563 208\n"); time.sleep(4)
(R / "pilot_cmd.txt").write_text("gym 1200\n"); time.sleep(4)
fc("bot 300", 12); fc("botfar 1500", 15); fc("botbed 120", 8)
print("moved in:", wait("moved in", 60))
# ---- Porter ----
fc("needs 100 100", 2); fc("job porter", 2); fc("box 300", 3)
fc("botcrew", 40)                      # stand next to the crew member until recruit_cd (30 s) is over
print("rejoined:", log().count("recruited") >= 2 or wait("no gift", 30))
fc("botfar 4000", 45)                  # away from base (bot must end > BASE_UU 800 from the bed), crew follows
fc("bothold Scrap 3", 2); fc("botcrew", 2)
print("took 3:", wait("bag=3", 40))
fc("botback", 5)
print("unloaded:", wait("unloaded 3 items", 120))
fc("boxes", 3)
# ---- Guard ----
fc("needs 10 100", 6)                  # tired follower goes to bed = at home without owner
print("home again:", log().count("went to bed") >= 1)
fc("botfar 4000", 30)                  # owner away so it is not re-recruited
fc("needs 100 100", 2); fc("job guard", 3); fc("enemy 1000", 3)
print("guard post:", wait("guard post", 30)); time.sleep(25)
fc("enemykill", 6)
print("guard clear:", wait("guard clear", 20))
fc("enemy 1000", 8); fc("needs 10 100", 6)
print("guard off duty:", wait("guard off duty", 15))
fc("needs 100 100", 6)
print("guard back on:", wait("guard back on duty", 15)); time.sleep(8)
fc("enemykill", 3); fc("status", 3)
print("client", "alive" if alive() else "DEAD")
cr = R / "faircrew_crumb.txt"; print("crumb:", cr.read_text() if cr.exists() else "none")
keep = ("porter", "guard", "job ", "thing", "bothold", "box ", "recruited", "moved in", "went ", "declined", "error", "enemykill", "botfar", "botback")
print("\n".join(l for l in log().splitlines() if any(k in l for k in keep))[-5000:])
