# Abiotic Factor AI mods (UE4SS Lua)

Fair-play AI mods for Abiotic Factor (Steam, Unreal Engine 5.4), written as UE4SS Lua mods. Single player / host only; multiplayer is not tested and not planned.

**Test stage.** Almost every check here was run by scripts: agents driving a test client or a hidden dedicated server on one PC. Human play-testing is still owed, and anything not listed as tested is unverified. The repo holds only our own scripts and notes: no game files, no object dumps.

## Mods

| Folder | What it does | Tested state |
|---|---|---|
| `FairSight` | Caps `LastSawTargetCheatDuration` (how long an AI keeps tracking your live position through walls after it lost sight) at 2 s for every AI controller. Sight and hearing are untouched. | Headless dedicated server: a spawned zombie went from 999999 to 2.0 (recorded in docs/AI-MAP.md section 8; the log file is not in this repo). Effect on play: unverified. |
| `FairDirector` | Pacing: when a player's stress (low health, recent damage, NPCs close by) is high, spawns relax for a while; after a long calm they build up again. Never touches NPC senses. | Unverified in a world. |
| `FairFps` | FPS text and a scrolling frame-time bar graph on the HUD, F8 toggle, frame-time log. | Real client, 2026-11-10: graph, toggle and log PASS (TESTPLAN.md). |
| `FairCrew` | Stranded scientists you recruit with food or healing items. They follow you, move in to a bed you build, decide by their rest and food, can work as porter or guard, and move like a player (stroll, jog, sprint, jump, crouch, ladder). | Crew harness rows H1-H13 all PASS in one run (docs/crew_harness_report.md). The walk row (H6) saw the follower moving in 4 of 12 samples; two earlier runs were weak (speed 60 and 73 uu/s, seen in 1 of 12 samples), so a smooth walk is unverified. Known gaps below. |
| `AfPilot` | Test-only driver: runs console and menu commands from a file, so tests need no mouse or window focus. Never leave it enabled in normal play. | Used by every client test. |
| `AFDump` | One-shot UE4SS object / usmap dump (development only; its output is not in this repo). | - |

### FairCrew: known gaps
- The crew run down the obstacle lane is flaky: 1 pass (harness run), 1 fail (a later run veered to the fence and gave up).
- Ladder: the body enters the game's own climb state, but the rise is driven by the mod in small teleport steps. Only the test gym's ladder was tried; ladders on real maps are unverified.
- Spawn: when a new body comes up more than 500 uu from its spot, the mod sets it to the spot directly (added on 11-11 after a scripted spawn on the client came up at the map origin).
- How the movement looks to a person is unverified; there is no usable video yet.
- Jobs (porter, guard) are set by a test command only; there is no in-game menu for them.
- Engine pathfinding requests fail for the spawned bodies, so they walk by direct moves plus a simple detour walker. It still gets stuck.
- A client Lua VM crash was seen in long runs on 11-12. Two later long runs did not show it; the cause is not proven fixed.
- Not covered: how enemies treat the crew, damage and death of a crew body, save and reload (crew are not saved).

## Install
1. Install UE4SS into `AbioticFactor\Binaries\Win64`.
2. Copy a mod folder into `ue4ss\Mods` and add a line `<ModName> : 1` to `ue4ss\Mods\mods.txt`. Or run `deploy.ps1 -Mods FairCrew,FairFps` after changing the Steam path at the top of that script.
3. The mods write their logs and read their command files under `C:/re/abioticfactor/` (hard-coded in the scripts). Create that folder, or change the paths, or you get no logs.

## Tests
- `TESTPLAN.md`: the test plan and the dated test log, with the log lines used as evidence (the log files themselves are not in the repo).
- `test/crew_harness.py`: one client run (about 8 minutes), rows H1-H13, PASS/FAIL table, exit code 1 on any FAIL.
- `test/`: the other row scripts (needs, jobs, movement probes, stress, gym screenshot and video attempts).
- `tools/selftest.ps1`: FairCrew self-test on a hidden dedicated server.

The test scripts are tied to the PC they were written on: they expect this repo at `C:/re/abioticfactor/mod`, `test/run_route.ps1` copied to `C:/re/abioticfactor/`, the game at the default Steam path, and `AfPilot` deployed. `AF_ADAPTER=<n>` picks the GPU the test client runs on. A client test sets `AfPilot : 1` in mods.txt and sets it back to 0 at the end (`test/vid_course.py` does not: it leaves the client running and AfPilot on). `tools/selftest.ps1` and `tools/srvgym.ps1` need the dedicated server (installed with steamcmd under `C:/re/abioticfactor/tools/steamcmd`, port 7779) with its own UE4SS; that setup was done by hand and is not scripted here.

## Docs
- `docs/crew_jobs_plan.md`: plan for crew jobs (porter and guard are built; the rest is parked).
- `docs/persona_plans.md`: how different kinds of players might meet the crew. Model predictions, not measurements.
- `docs/research_player_sync.md`: how a player is synced and drawn in multiplayer (from the object dump and general engine knowledge; not checked in game).
- `docs/research_multiagent_testing.md`: how studios and researchers test games and robots with many agents; every source page was opened.
- `docs/crew_harness_report.md`: the latest harness report.
- `docs/AI-MAP.md`: static map of the game's AI (controllers, perception, spawn director), the places where the AI acts on information its senses did not give it, and the hook plan the mods started from.

The docs cite `dump/UE4SS_ObjectDump.txt` by line number. That file is made from the game by `AFDump` and is not included.
