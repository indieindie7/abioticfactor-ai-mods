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
fc("ownbot", 2); fc("botplace -17750 13900", 2); fc("crewtobot", 2); fc("botgo -900 600", 1)
best_v, best_a, mv, n, last = 0.0, 0.0, 0, 0, None
for _ in range(12):
    fc("anim", 1.3)
    for a in find(r"anim \S+ at (\S+) vel=(-?\d+) animSpeed=(\S+)")[-1:]:
        n += 1; mv += float(a.group(2)) > 50; best_v = max(best_v, float(a.group(2)))
        try: best_a = max(best_a, float(a.group(3)))
        except ValueError: pass
arr = wait(r"bot arrived", 60); time.sleep(6); fc("cam", 2); ap = find(r"cam .* apart (\d+)")
row("H5", "crew follows the owner (apart < 600 uu after the walk)", arr and bool(ap) and int(ap[-1].group(1)) < 600, f"arrived={arr} apart={ap[-1].group(1) if ap else '?'}")
row("H6", "walking: velocity > 50, anim Speed > 50, moving in >= 2 samples", best_v > 50 and best_a > 50 and mv >= 2, f"max vel={best_v:.0f} max animSpeed={best_a:.0f}, moving in {mv}/{n} samples")
# H7 move in: owner places a cot, crew settles
fc("botbed 120", 4); fc("crewtobot", 2)
row("H7", "moved in to the owner's bed", wait(r"moved in Crew", 60), (find(r"moved in .*") or [None])[-1].group(0)[:60] if find(r"moved in .*") else "none")
# H8 needs: a settled crew member that is tired stays home and its rest recovers
fc("needs 5 100", 2); fc("status", 3); r0 = len(find(r"crew 1 \S+\[(\w+) f=\d+ r=(\d+)")); time.sleep(30); fc("status", 2); wait(r"x^", 0); [time.sleep(2) for _ in range(5) if len(find(r"crew 1 \S+\[(\w+) f=\d+ r=(\d+)")) <= r0]
st = find(r"crew 1 \S+\[(\w+) f=\d+ r=(\d+)")
ok = len(st) > r0 >= 1 and st[-1].group(1) == "home" and int(st[-1].group(2)) > int(st[r0 - 1].group(2))
row("H8", "tired crew stays home, rest recovers", ok, f"{st[r0 - 1].group(0)} -> {st[-1].group(0)}" if len(st) > r0 >= 1 else "no status lines")
# H10-H13 parkour course: spare body, then the recruited crew member, over the hurdle, under the bar, up the ladder
def pos():
    fc("bodypos", 2); p = find(r"bodypos (-?\d+),(-?\d+),(-?\d+)"); return tuple(int(x) for x in p[-1].groups()) if p else None
def lane(i, who):
    p0 = pos(); k = len(find(r"mo blocked")); fc("mvspd 500 28", 1.5); fc("mvauto 0 700", 30); p = pos()
    row(i, f"{who}: hurdle by jump, bar by crouch (ends > 620 uu down the lane, bar ends at 600)", bool(p) and bool(p0) and p[1] - p0[1] > 620 and abs(p[0] - p0[0]) < 150, f"start={p0} end={p} blocked tries={len(find(r'mo blocked')) - k}")
def ladder(i, who):
    k = len(find(r"climb top")); fc("bodytp -150 900", 3); fc("mvup", 18); p = pos(); c = find(r"climb top at \S+")
    row(i, f"{who}: walks to the ladder and climbs to the platform (Z > 380)", len(c) > k and bool(p) and p[2] > 380, f"end={p} " + (c[-1].group(0) if len(c) > k else "no climb top"))
pc("tpabs -17709 13563 208", 4); fc("body 300", 4); fc("bodyctl", 3); fc("parkour", 4)
lane("H10", "test body"); ladder("H11", "test body")
fc("mvwho crew", 2); fc("bodytp 0 0", 3)
lane("H12", "crew member"); ladder("H13", "crew member"); fc("mvwho body", 2)
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
