# 11-13 Porter real items: bot owner (virtual hold -> real chest items), then local player as owner (real take -> real chest items).
import time, pathlib, subprocess, re
R = pathlib.Path("C:/re/abioticfactor")
def alive(): return b"AbioticFactor-Win64" in subprocess.run(["tasklist"], capture_output=True).stdout
def fc(c, w): (R / "faircrew_cmd.txt").write_text(c + "\n"); time.sleep(w)
def pc(c, w): (R / "pilot_cmd.txt").write_text(c + "\n"); time.sleep(w)
def log(): return (R / "faircrew_log.txt").read_text(errors="replace")
def wait(s, t, n=1):
    t0 = time.time()
    while time.time() - t0 < t and alive():
        if log().count(s) >= n: return True
        time.sleep(2)
    return False
subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(R / "run_route.ps1"), "bandage", "6"])
pc("tpabs -17709 13563 208", 4); pc("gym 1200", 4)
fc("bot 300", 12); fc("ownbot", 2); fc("botfar 1500", 2)
print("bot at bed spot:", wait("bot arrived", 150)); fc("botbed 120", 6); fc("crewtobot", 2)   # the bot walker stalls at times: wait, never assume
print("moved in:", wait("moved in", 60))
fc("needs 100 100", 2); fc("job porter", 2); fc("box 300", 3); fc("botcrew", 5)
print("recruited:", wait("recruited", 60, 2))
fc("bothold Bandage 3", 2); fc("crewtobot", 2)     # owner at base: each item is taken, then put into the chest (the long haul walk is row J2)
print("K1 bot owner, 3 unloads of real items:", wait("real items into box", 150, 3))
fc("boxslots", 4)
# ---- player owner ----
fc("haul bandage", 2); fc("ownslots", 4); fc("ownme 1", 4)
m = re.findall(r"ownme .* home (-?\d+) (-?\d+) (-?\d+)", log())
if m:
    x, y, z = map(int, m[-1]); pc(f"tpabs {x + 120} {y + 120} {z + 100}", 5)
print("home:", m[-1] if m else None)
print("K2 took real item:", wait("(real item)", 90))
print("K2 unloaded twice more:", wait("real items into box", 150, 6))
print("K3 box full, rest given back:", wait("gave back 1 Bandage", 150))
time.sleep(8)
fc("boxslots", 4); fc("ownslots", 4); fc("status", 3)
print("client", "alive" if alive() else "DEAD")
cr = R / "faircrew_crumb.txt"; print("crumb:", cr.read_text(errors="replace")[-300:] if cr.exists() else "none")
keep = ("porter", "job ", "thing", "bothold", "slots", "ownme", "haul", "recruited", "moved in", "error", "ownbot")
print("\n".join(l for l in log().splitlines() if any(k in l for k in keep))[-6000:])
print("pilot:", (R / "pilot_out.txt").read_text(errors="replace")[-300:])
