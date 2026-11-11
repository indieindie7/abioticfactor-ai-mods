# Drive FairCrew TESTPLAN rows 6-12 with no input focus (needs run_route.ps1 first). Prints the log lines per row.
import re, time, pathlib
R = pathlib.Path("C:/re/abioticfactor"); LOG = R / "faircrew_log.txt"
def fc(c): (R / "faircrew_cmd.txt").write_text(c + "\n")
def pilot(c): (R / "pilot_cmd.txt").write_text(c + "\n")
def sleep(s): time.sleep(s)
def status():
    fc("status"); sleep(2)
    return [l for l in LOG.read_text(errors="replace").splitlines() if " F10 " in l][-1]
mark = [0]
def row(name):
    lines = LOG.read_text(errors="replace").splitlines(); new = lines[mark[0]:]; mark[0] = len(lines)
    print(f"== {name}"); [print("  ", l[:230]) for l in new if " crew " not in l or " F10 " in l]
def me(s): x, y = re.search(r"me=(-?\d+),(-?\d+)", s).groups(); return float(x), float(y)
mark[0] = len(LOG.read_text(errors="replace").splitlines())
fc("spawn 150"); sleep(14); status(); row("6 recruit")
pilot("tp 1500 0"); sleep(6); status(); sleep(6); status(); row("7 follow 15 m")
s = status(); bx, by, bz = map(float, s.split("beds@")[1].split(";")[0].split(",")); mx, my = me(s)
pilot(f"tp {bx - mx + 120:.0f} {by - my:.0f}"); sleep(10); status(); sleep(10); status(); row("9 bed move-in")
pilot("tp 4000 0"); sleep(12); status(); row("10 stays home")
pilot("tp -4000 0"); sleep(20); status(); row("11 re-gift at bed")
pilot("tp 4000 0"); sleep(200); status(); row("12 decay -> went home")
