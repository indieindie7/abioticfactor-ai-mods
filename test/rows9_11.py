# FairCrew rows 6, 9-12 with our own cot spawned next to the player (the map's only bed streams out). Needs run_route.ps1 + AfPilot : 1.
import re, time, pathlib
R = pathlib.Path("C:/re/abioticfactor"); LOG = R / "faircrew_log.txt"; PO = R / "pilot_out.txt"
def fc(c): (R / "faircrew_cmd.txt").write_text(c + "\n")
def pilot(c): (R / "pilot_cmd.txt").write_text(c + "\n"); time.sleep(2); print("   pilot:", PO.read_text(errors="replace").splitlines()[-1])
def status():
    fc("status"); time.sleep(2)
    return [l for l in LOG.read_text(errors="replace").splitlines() if " F10 " in l][-1]
mark = [len(LOG.read_text(errors="replace").splitlines())]
def row(name):
    lines = LOG.read_text(errors="replace").splitlines(); new = lines[mark[0]:]; mark[0] = len(lines)
    print(f"== {name}"); [print("  ", l[:230]) for l in new if " crew " not in l or " F10 " in l]
fc("spawn 150"); time.sleep(14); status(); row("6 recruit")
pilot("bed 600 0"); time.sleep(3); status(); row("bed spawned")
pilot("tp 480 0"); time.sleep(12); status(); time.sleep(8); status(); row("9 bed move-in")
pilot("tp 4000 0"); time.sleep(12); status(); row("10 stays home")
pilot("tp -4000 0"); time.sleep(20); status(); row("11 re-gift at bed")
pilot("tp 4000 0"); time.sleep(200); status(); row("12 decay -> went home")
pilot("arena 3000"); time.sleep(3); status(); row("arena smoke")
