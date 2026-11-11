# Agent-vs-agent FairCrew rows: an NPC "bot owner" (virtual gift) recruits, leads, beds and leaves a crew NPC. No player input. Needs run_route.ps1.
import time, pathlib, sys
R = pathlib.Path("C:/re/abioticfactor"); LOG = R / ("faircrew_srv_log.txt" if "srv" in sys.argv else "faircrew_log.txt")   # arg srv = dedicated test server (mod/tools/srvgym.ps1)
def fc(c, wait): (R / "faircrew_cmd.txt").write_text(c + "\n"); time.sleep(wait)
mark = [len(LOG.read_text(errors="replace").splitlines())]
def row(name):
    fc("status", 2); lines = LOG.read_text(errors="replace").splitlines(); new = lines[mark[0]:]; mark[0] = len(lines)
    print(f"== {name}"); [print("  ", l[:260]) for l in new if " crew " not in l or " F10 " in l]
(R / "pilot_cmd.txt").write_text("tpabs -17709 13563 208" + chr(10)); time.sleep(4)  # nav-meshed start room (run 1-3 sat at -13229: no path)
(R / "pilot_cmd.txt").write_text("gym 1200" + chr(10)); time.sleep(4); po = R / "pilot_out.txt"; print("== gym", po.read_text(errors="replace").strip().splitlines()[-1] if po.exists() else "no pilot_out.txt")
fc("bot 300", 12); row("6 bot recruits crew")
fc("botfar 1500", 20); row("7 crew follows bot 15 m")
fc("botbed 120", 10); row("9 bed move-in")
fc("botfar 4000", 30); row("10 crew stays home when bot leaves")
fc("botback", 40); row("11 bot back at bed: crew re-recruited?")
fc("botfar 4500", 25); fc("status", 2); fc("botfar 4500", 260); row("12 decay -> went home")
