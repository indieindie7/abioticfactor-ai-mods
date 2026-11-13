# FairCrew crew harness (11-13): one client run, agent-vs-agent (bot owner + crew, both player-pipeline bodies).
# Each row = commands + a check on NEW faircrew_log.txt lines. Prints a PASS/FAIL table, writes crew_harness_report.md, exit 1 on any FAIL.
# Usage: py -3.13 -I mod/test/crew_harness.py [--keep]   (--keep leaves the client running)
import time, pathlib, subprocess, re, sys, datetime
R = pathlib.Path("C:/re/abioticfactor")
M = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\AbioticFactor\AbioticFactor\Binaries\Win64\ue4ss\Mods\mods.txt")
LOG = R / "faircrew_log.txt"
def alive(): return b"AbioticFactor-Win64" in subprocess.run(["tasklist"], capture_output=True).stdout
def fc(c, w=1.5): (R / "faircrew_cmd.txt").write_text(c + "\n"); time.sleep(w)
def pc(c, w=1.5): (R / "pilot_cmd.txt").write_text(c + "\n"); time.sleep(w)
def new(): return LOG.read_text(errors="replace").splitlines()[N0:] if LOG.exists() else []
def find(rx): return [m for m in (re.search(rx, l) for l in new()) if m]
def wait(rx, t, n=1):
    t0 = time.time()
    while time.time() - t0 < t and alive():
        if len(find(rx)) >= n: return True
        time.sleep(1.5)
    return len(find(rx)) >= n
ROWS = []
def row(i, name, ok, ev): ROWS.append((i, name, "PASS" if ok else "FAIL", ev)); print(f"{i} {'PASS' if ok else 'FAIL'} {name}: {ev}", flush=True)

M.write_text(M.read_text().replace("AfPilot : 0", "AfPilot : 1"))
subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(R / "run_route.ps1"), "bandage", "1"])
N0 = 0
pc("tpabs -17709 13563 208", 4); pc("gym 1200", 6)
fc("bot 300", 8)
# H1 spawn: both are player bodies with the stock AI controller
b = find(r"bot owner BotOwner at"); c = find(r"spawn (Crew\d+) at .* ctrl=(\S+)")
row("H1", "bot owner + crew spawn with AI controller", bool(b) and bool(c) and "AI_Controller" in c[-1].group(2), c[-1].group(0)[:90] if c else "no spawn line")
# H2 random look: 9 parts each, no error, the two differ
lk = find(r"look (BotOwner|Crew\d+) (.*)")
ok = len(lk) >= 2 and all(l.group(2).count("=") == 9 and "ERR" not in l.group(2) for l in lk[-2:]) and lk[-1].group(2) != lk[-2].group(2)
row("H2", "random look, 9 parts, two bodies differ", ok, (lk[-1].group(2)[:80] if lk else "no look line"))
# H3 our bodies are not players
fc("who", 2); w = find(r"who bodies=(\d+) real=(\d+) crew=(\d+)")
row("H3", "bodies=3 real players=1", bool(w) and w[-1].groups()[:2] == ("3", "1"), w[-1].group(0) if w else "no who line")
# H4 recruit by gift (bot holds a virtual gift)
row("H4", "recruited with a gift", wait(r"recruited Crew", 40), (find(r"recruited .*") or [None])[-1].group(0)[:80] if find(r"recruited .*") else "none")
# H5 follow + H6 walk state: owner walks off, crew walks after it
fc("ownbot", 2); fc("botplace -17750 13900", 2); fc("crewtobot", 2); fc("botgo -400 300", 1)
best_v, best_a, mv, n, last = 0.0, 0.0, 0, 0, None
for _ in range(12):
    fc("anim", 1.3)
    for a in find(r"anim \S+ at (\S+) vel=(-?\d+) animSpeed=(\S+)")[-1:]:
        n += 1; mv += float(a.group(2)) > 50; best_v = max(best_v, float(a.group(2)))
        try: best_a = max(best_a, float(a.group(3)))
        except ValueError: pass
arr = wait(r"bot arrived", 60); time.sleep(6); fc("cam", 2); ap = find(r"cam .* apart (\d+)")
row("H5", "crew follows the owner (apart < 600 uu after the walk)", arr and bool(ap) and int(ap[-1].group(1)) < 600, f"arrived={arr} apart={ap[-1].group(1) if ap else '?'}")
row("H6", "walking: velocity > 50 and anim blueprint Speed > 50", best_v > 50 and best_a > 50, f"max vel={best_v:.0f} max animSpeed={best_a:.0f}, moving in {mv}/{n} samples")
# H7 move in: owner places a cot, crew settles
fc("botbed 120", 4); fc("crewtobot", 2)
row("H7", "moved in to the owner's bed", wait(r"moved in Crew", 60), (find(r"moved in .*") or [None])[-1].group(0)[:60] if find(r"moved in .*") else "none")
# H8 needs: a settled crew member that is tired stays home and its rest recovers
fc("needs 5 100", 2); fc("status", 2); time.sleep(30); fc("status", 2)
st = find(r"crew 1 \S+\[(\w+) f=\d+ r=(\d+)")
ok = len(st) >= 2 and st[-1].group(1) == "home" and int(st[-1].group(2)) > int(st[-2].group(2))
row("H8", "tired crew stays home, rest recovers", ok, f"{st[-2].group(0)} -> {st[-1].group(0)}" if len(st) >= 2 else "no status lines")
# H9 health of the run
errs = [l for l in new() if re.search(r"cmd_step error|ERR ", l)]
row("H9", "client alive, no Lua errors", alive() and not errs, f"alive={alive()} errors={len(errs)}" + (" " + errs[0][-80:] if errs else ""))
if "--keep" not in sys.argv:
    subprocess.run(["taskkill", "/F", "/IM", "AbioticFactor-Win64-Shipping.exe"], capture_output=True)
M.write_text(M.read_text().replace("AfPilot : 1", "AfPilot : 0"))
out = [f"# FairCrew crew harness {datetime.datetime.now():%Y-%m-%d %H:%M}", "", "| row | check | result | evidence |", "|---|---|---|---|"]
out += [f"| {i} | {n} | {r} | {e} |" for i, n, r, e in ROWS]
(R / "crew_harness_report.md").write_text("\n".join(out) + "\n", encoding="utf-8")
sys.exit(1 if any(r == "FAIL" for _, _, r, _ in ROWS) else 0)
