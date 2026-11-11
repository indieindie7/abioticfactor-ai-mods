# Test plan: FairCrew v0.2 + FairFps v0.1 (single player / host)

Restart the game first: mods load at game start. Logs: `C:/re/abioticfactor/faircrew_log.txt`, `C:/re/abioticfactor/fairfps_log.txt`.

| # | Do | Expect | Log line |
|---|---|---|---|
| 1 | Load a level | FPS text + frame-time bar graph top left | `graph hooked on BP_HUD:ReceiveDrawHUD` |
| 2 | Press F8 twice | graph off, then on | `toggle false`, `toggle true` |
| 3 | Play 1 min | | `frame ms avg=...` every 10 s |
| 4 | Press F9 | scientist appears 3 m ahead | `F9 spawn near player`, `spawn ... ctrl=AI_Controller_NPC_BossAlly...` |
| 5 | Wait 20 s, empty hands | it wanders around, does NOT join | `crew 1 ...[idle` positions change |
| 6 | Hold food/bandage next to it 4 s, press F10 | it takes 1 item (stack -1), joins | `F10 held=<row> gift=true`, `recruited ... took=true` |
| 7 | Walk 20 m away, around corners | it follows | `[follow` positions change |
| 8 | Fight an enemy with it near | it fights; enemies treat it as hostile/target | (watch) |
| 9 | Build/use a bed, stand next to it 3 s with follower near | it moves in, stays around bed | `moved in ... bed=` |
| 10 | Walk away 40 m | it stays at the bed | `[home` |
| 11 | Gift it again at the bed | follows again | `recruited` |
| 12 | Leave a follower 30+ m behind for ~1 min | friendship drops; at 0 it goes home | `went home` |
| 13 | Save, quit, reload | (crew are not saved; new ones spawn every 10 min) | |

Report: pass/fail per row, or just say "done" and Claude reads the logs.

## Automated self-test (FairCrew, no player needed)

`powershell -NoProfile -ExecutionPolicy Bypass -File tools\selftest.ps1` starts the dedicated server hidden with `AF_FAIRCREW_SELFTEST=1`, injects UE4SS, runs `FairCrew/Scripts/selftest.lua` and prints `faircrew_selftest.md` (about 3 minutes).

A scripted mock player (a Lua table) drives the real mod logic against real spawned scientists and a real cot: spawn, wander, no-gift / wrong-item refusal, gift recruit (1 item taken), follow, bed move-in, staying home, claimed bed, re-gift, friendship decay, bed freed.

It does not cover: rendering, a real player's inventory, combat, save/reload, multiplayer, a scientist dying (step 13 is SKIP: the test cannot destroy its own actor on the server). Step 14 is INFO only. Those still need the manual rows above.

Last result 2026-11-10: 12/12 pass, 1 SKIP, 1 INFO (one run after the last fix; earlier runs failed on walking until the movement-mode and movement-tick fixes went in).

Server note: UE4SS v3.0.1-1214 dies at start ("StaticAlignment_Private is not valid") when Windows loads the server exe at an address whose low 32 bits are 0x80000000 or more. The test server exe here has ASLR switched off (DllCharacteristics 0x8160 -> 0x8100) so it always loads at 0x140000000.

## In-game run on the real client, 2026-11-10 13:05-13:32
Standalone `open Facility` (no hosted world, no inventory; the game sat on the job-selection screen while the keys were pressed). Evidence is mod logs plus screenshots of the HUD corner. Details: ../NOTES.md.

| Row | Result | Evidence |
|---|---|---|
| 1 FPS number | PASS | FPS + ms text top right in every screenshot |
| 1 graph bars | FAIL | no graph in any screenshot; `stat unitgraph` draws nothing in this build |
| 2 F8 twice | log only | `toggle false ok=true`, `toggle true ok=true`; on-screen change not confirmed |
| 3 frame-time log | PASS | `frame ms avg` every 10 s, 7.2-10.8 ms |
| 4 F9 spawn | PASS (log) | `spawn NarrativeNPC_BossAlly ... ctrl=AI_Controller_NPC_BossAlly_C`; not seen on screen |
| 5 wander, no join | PASS (log) | idle, f=0, moved about 690 uu in 22 s, no owner |
| 6-13 | NOT RUN | need a held gift item in a hosted world; only the server self-test covers the logic |

Crashes found: (1) Lua `SetText(FText())` kills the game (pilot `text` op removed); (2) F9 in the intro level V_Intro crashed the game 1 s after the spawn (access violation, cause not found); F9 in Facility did not crash in 35 s.

`AfPilot/` is a test-only driver (command file -> console/menu calls). Never ship it enabled.

## FairFps v0.2 re-test, 2026-11-10 22:31-22:34 (real client, Facility)
| Row | Result | Evidence |
|---|---|---|
| 1 graph bars + text | PASS | log `graph hooked on BP_HUD:ReceiveDrawHUD` 22:31:50; screenshot: 120 bars, 60/30 fps lines, "fps 153 avg 167 worst 117 (8 ms)" top left |
| 2 F8 twice | PASS | graph region 0 lit pixels after 1st F8, 2602 after 2nd; log `toggle false` / `toggle true` |
| 3 frame-time log | PASS | every 10 s over all frames, e.g. avg 5.8 ms, 1735 frames |
Note: the graph draws on the HUD canvas, so full-screen menus (job/trait select) cover it.

## FairCrew rows 6-13 re-test (11-10 23:08-23:13, real client, no input focus: run_route.ps1 + rows6_12.py)
| Row | Result | Evidence (faircrew_log.txt) |
|---|---|---|
| 6 | PASS | `recruited NarrativeNPC_BossAlly with Bandage took=true friend=60` 4 s after spawn at 150 uu; stack 3->2 not read (unverified) |
| 7 | PASS (log) | after `tp 1500 0` follower moved -19014 -> -17772 (63 uu from player) |
| 8 | not run | needs a watched fight |
| 9 | BLOCKED | the only bed seen (-15581,10985) streams out when the player stands there (beds 1 -> 4 far -> 0); follower also stalled 1700 uu away. Needs a bed placed in the player's own area |
| 10-11 | BLOCKED | depend on 9 |
| 12 | PASS | player 4000 uu away: f 63 -> 0, `went home NarrativeNPC_BossAlly` at 23:11:09, then `[idle f=0` |
| 13 | N/A | crew are not saved (by design) |
Fixes from this run: CLASSES only NarrativeNPC_BossAlly (_Heavy/_Sniper spawn without AI and vanish); take_gift no longer calls GetCurrentHeldItem (crash FField::AddCppProperty); beds re-found every tick (crash 4, stale bed after streaming; no crash in this run).

## 11-10 23:18-23:59 own cot + agent-vs-agent runs
- Own cot (AfPilot `bed 600 0`) next to the player, map bed not needed (rows9_11.py):
  - Row 9 PASS: `moved in ... bed=Deployed_Furniture_Cot_Military_C_...` 3 s after the owner stood at the cot.
  - Row 10 FAIL then fixed: owner still holding the gift re-recruited the crew 6 s after move-in (ate a 2nd Bandage). Fix: 30 s recruit cooldown after move-in. Re-test with the player: unverified.
  - Row 12 PASS again (`went home` 23:23:40). `arena 3000` smoke: floor + cot spawned (cot=true); not used for rows (no navmesh up there).
- Agent-vs-agent (botrows.py, FairCrew BOT owner = NPC with a virtual Bandage, no player):
  - Row 6 PASS (bot recruits crew), row 9 PASS (bot at cot -> `moved in`), cooldown PASS (no re-recruit inside 30 s).
  - Rows 7/10/11/12 NOT RUN: the bot NPC never walks. MoveToLocation returns 2 (request ok) but the pawn stays put; pathfinding request fails first (direct=true). Cause unverified (likely the BossAlly behaviour tree overrides the move).
  - Run 4 log shows 4 F9 spawns at 23:53:39-41 and the player moving: not from the driver (keyboard input on the test client).

## 11-11 07:32-07:54 gym + bot walker (dedicated test server)
- New: AfPilot `gym [half]` (default 1200 uu): 8 wall halves with 3 m door gaps + 4 corner posts (engine cubes) + 2 cots around the player, or around PlayerStart when there is no player. FairCrew bot walker `bot_goal`: StopLogic on the bot's BrainComponent, MoveToLocation re-issued each 1 s, stuck <50 uu for 2 s -> glide (K2_SetActorLocation, 600 uu/s, test bot only); `botfar` with no reachable navmesh point glides +X. Runner mod/tools/srvgym.ps1 + `botrows.py srv`.
- Client runs 07:32 + 07:35: UE4SS died in init, "Fatal Error: [FName::StaticAlignment] StaticAlignment_Private is not valid" (ASLR coin flip per boot, NOTES 11-10 12:10). Same ASLR-off patch on the client exe was BLOCKED by the auto-mode classifier; client exe untouched, no .bak-aslr. Client mod tests are off until a reboot re-rolls it or the user allows the patch.
- Server run 2 (srvgym_out2.txt), gym centre -14748 15992 21565, boxes=12 cots=2, all agent-vs-agent:
  | Row | Result | Evidence |
  |---|---|---|
  | 6 recruit | PASS | 07:47:31 recruited with Bandage friend=60 |
  | 7 follow 15 m | PASS | bot glided to -12870; crew `follow` at -12916 (from -14198) |
  | 9 bed move-in | PASS | 07:48:06 moved in, state home |
  | 10 stays home | PASS | bot at -8932 (3.9 k uu away), crew `home` at -12870,15721 |
  | 11 owner back | observed | bot back 07:48:56, crew stays `home` f=63, no re-recruit in 32 s |
  | 12 decay | not shown | crew in `home` kept f=63 for 4 min with the bot 4.5-9 k uu away; decay/"went home" only seen from `follow` (11-10 player run) |
- Open: the bot walked only by glide (MoveToLocation r=2 after StopLogic still no motion, and no navmesh at the server PlayerStart: "no reachable point"). Last status shows bot=0,0 after gliding 9 k uu +X (bot gone, cause unverified). An extra crew entry `idle f=0` wanders the gym (identity unverified). Gym look is unverified (no screenshot: server has no renderer).

## 11-11 11:52-11:58 client gym run 6 (exe ASLR-off patch, bots = navigation invokers)
- Nav finding: RecastNavMesh.RuntimeGeneration = 2 (Dynamic), NavigationSystemV1.bGenerateNavigationOnlyAroundNavigationInvokers = true: the game builds navmesh only around invokers. FairCrew now registers the test bot and (TEST/bot mode only) spawned NPCs via RegisterNavigationInvoker(a, 3000, 5000); log "nav invoker true" (call accepted; effect on tiles unverified).
- Gym centre -17709 13563 118, `bot 300`. All agent-vs-agent, faircrew_log.txt:
  | Row | Result | Evidence |
  |---|---|---|
  | 6 recruit | PASS | 11:54:04 recruited with Bandage friend=60 |
  | 7 follow | PASS | bot to -19115,13948; crew `follow` at -18862,13947 (from -17262,13605) |
  | 9 bed move-in | PASS | 11:54:38 moved in, 11:54:46 state home |
  | 10 stays home | PASS | bot at -17920,15813 (2.0 k uu away), crew `home` at -18862,14008 |
  | 11 owner back | PASS (differs from server run) | bot back 11:55:29, 11:55:33 recruited again friend=73.45, state follow |
  | 12 decay | not shown | friend only rose (63 -> 88) |
- Bot walking: real MoveTo covered 1494 of 1769 uu, 0.3 k of 2291, 0.5 k of 2165, 2412 of 2523, 1.3 k of 2607 before "stuck" -> glide. Every request `direct=true` (pathfinding request fails, straight-line move works), so the invoker did not give the bot a path. Likely stops = gym walls on the straight line (unverified).
- Bad spot: `bot 400` (-17313,13619) spawns the bot at 0,0,0 and it dies, 3 of 3; cause unverified.
- Human-only checks left: gym look in game; NPC movement look; player re-test of recruit cooldown; design: should `home` crew re-recruit on owner return (client did, server did not) and should it decay.

