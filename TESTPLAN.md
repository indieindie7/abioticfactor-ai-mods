# Test plan and test log: FairCrew v0.2 + FairFps v0.2 (single player / host)

How to read this file: the table below is the first manual plan (2026-11-10). Every later section is a dated run, oldest first, and is left as it was written. Sections before 11-13 describe the NarrativeNPC ally bodies the crew used then (rows 4 and 8 below included); since 11-13 the crew are player bodies. The newest sections at the end give the current state. Log and output files named in this file (`*_out*.txt`, `*_log.txt`, crash folders) are local test output and are not in the repo.

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

Report: pass/fail per row, or just say "done" and the logs are read instead.

## Automated self-test (FairCrew, no player needed)

`powershell -NoProfile -ExecutionPolicy Bypass -File tools\selftest.ps1` starts the dedicated server hidden with `AF_FAIRCREW_SELFTEST=1`, injects UE4SS, runs `FairCrew/Scripts/selftest.lua` and prints `faircrew_selftest.md` (about 3 minutes).

A scripted mock player (a Lua table) drives the real mod logic against real spawned scientists and a real cot: spawn, wander, no-gift / wrong-item refusal, gift recruit (1 item taken), follow, bed move-in, staying home, claimed bed, re-gift, friendship decay, bed freed.

It does not cover: rendering, a real player's inventory, combat, save/reload, multiplayer, a scientist dying (step 13 is SKIP: the test cannot destroy its own actor on the server). Step 14 is INFO only. Those still need the manual rows above.

Last result 2026-11-10: 12/12 pass, 1 SKIP, 1 INFO (one run after the last fix; earlier runs failed on walking until the movement-mode and movement-tick fixes went in).

Server note: UE4SS v3.0.1-1214 dies at start ("StaticAlignment_Private is not valid") when Windows loads the server exe at an address whose low 32 bits are 0x80000000 or more. The test server exe here has ASLR switched off (DllCharacteristics 0x8160 -> 0x8100) so it always loads at 0x140000000.

## In-game run on the real client, 2026-11-10 13:05-13:32
Standalone `open Facility` (no hosted world, no inventory; the game sat on the job-selection screen while the keys were pressed). Evidence is mod logs plus screenshots of the HUD corner. Details are in the project notes (not in this repo).

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
- Client runs 07:32 + 07:35: UE4SS died in init, "Fatal Error: [FName::StaticAlignment] StaticAlignment_Private is not valid" (ASLR coin flip per boot). The same ASLR-off patch was not applied to the client exe (untouched, no .bak-aslr). Client mod tests were off at that point (until a reboot re-rolls it or the patch is allowed).
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


## 11-11 12:10-12:18 crew needs: rest + fed decide (client gym, agent-vs-agent)
- Design rule (11-11): the crew decide whether to join by how well rested and fed they are. FairCrew: each crew member has rest + fed 0..100 (start 50/50). fed -1 per 30 s always; rest +1 per 6 s at home within 600 uu of the own bed, -1 per 18 s while following; a gift adds fed +40 (gifts.lua has no food/healing split yet, a Bandage feeds too).
- Settled crew (has a bed) asked by an owner lingering 4 s within 300 uu: rest < 60 -> declines "tired"; fed < 40 and no gift -> declines "hungry"; fed < 40 with gift -> eats it and joins; rested + fed -> joins with no gift. Decline = 30 s cooldown. A follower with a bed whose rest or fed drops below 15 walks home ("went to bed"), keeps the bed. Wild crew (no bed) still needs a gift.
- Test commands: `needs <rest> <fed>`, `botgift 0|1`, `botcrew`. Script mod/test/needsrows.py. Status shows r= h=.
  | Row | Result | Evidence (faircrew_log.txt) |
  |---|---|---|
  | N1 tired declines | PASS | 12:12:35 declined: tired rest=55 fed=87; joined by itself at 12:13:08 with rest=61 |
  | N2 hungry, no gift declines | PASS | 12:16:43 declined: hungry rest=85 fed=19 |
  | N3 hungry + gift eats, joins | PASS | 12:17:16 recruited with Bandage took=true rest=90 fed=58 |
  | N4 tired follower goes to bed | PASS | 12:14:50 and 12:16:10 went to bed: tired rest=10 fed=80 |
  | N5 rested + fed joins, no gift | PASS | 12:15:25 recruited with no gift rest=84 fed=79 |
- Fixed after the run (not re-run): recruit friendship could pass 100 (log showed 107.85), now capped.
- Not tested: natural decay over real time (values were set by `needs`), "hungry follower goes to bed", player as owner. Numbers are first guesses; feel needs a human.


## 11-12 13:44-14:26 autonav-style bot detours + hungry follower (client gym, 4 runs)
Autonav test. Walker (FairCrew main.lua): stuck 4 s -> detour heading from HEAD = +45,-45,+90,-90,+135,-135 off the goal direction, 400 uu sub-waypoint by direct MoveTo, "ok" if it moved >= 200 uu; spot memory (stuck again within 150 uu of a tried spot -> same heading with leg 800, 1200, then next heading); glide only after all headings at a spot fail or 16 ok detours. move_to to the goal is re-issued only while not moving. No line traces.
- Run 1 13:44-13:48 INVALID: GPU load 92-96 % from other jobs, client ~2 fps (fairfps_log.txt), crashed 13:48:04.
- Run 2 13:56-14:03 (~70 fps, no spot memory): 1 arrival glide=false (13:59:09, 23.8 s), 1 glide after 6 headings blocked (13:57:53), then a loop at -18475,14716: +90 "ok" ten times, bot walked back to the same spot each time.
- Run 3 14:06-14:07 (spot memory): 1 arrival glide=false (14:07:34, 16.0 s); client crashed 14:07:57.
- Run 4 14:17-14:26 (crumbs on, no crash): 13 detours ok, 8 blocked, 0 glides, 1 arrival glide=false (14:20:37, 14.0 s). On the other legs distance-to-go did not shrink after "ok" detours (e.g. 1742 -> 1825 uu) before the next test command replaced the goal.
- Verdict: PARTIAL. Detours move the bot off a stuck spot and it sometimes arrives without gliding; blind headings do not reliably make progress to the goal. Why the straight MoveTo stalls in the gym is unverified (walls assumed, not measured).
- Crashes: 2 of 4 runs, access violation inside UE4SS on the game thread from a Lua callback (two crash folders under Saved/Crashes). Cause unverified; did not recur in run 4 with breadcrumbs (crumb(), flag CRUMBS, file faircrew_crumb.txt). Not seen in the 11-11 runs.
- Hungry follower (hungry.py, run 4): PASS "went to bed ... hungry rest=80 fed=10" 14:25:11; PASS "declined ... hungry rest=84 fed=9" 14:25:44 (botgift 0). Rest rose 46 -> 84 at home, fed fell 10 -> 9 in real time (status lines). Join with no gift after needs 100 100 not shown here (crew was already following).
- Lesson: check nvidia-smi before a client run; at ~2 fps walk tests are meaningless.


## 11-12 15:40-18:20 crash hunt (client, FairCrew)
Tool: test/stress.py <minutes> (gym + random botfar/botback/botcrew every 4-14 s; prints alive|DEAD, last breadcrumb).
Breadcrumbs: `local CRUMBS = true` in FairCrew main.lua writes the last step to faircrew_crumb.txt.

| Run | Build | Result |
|---|---|---|
| 1 | 3 LoopAsync loops | DEAD 1.6 min, crumb "tick" |
| 2 | same + fine crumbs | alive 25.1 min |
| 3 | same | DEAD 20.2 min, crumb "beds GetFullName" |
| 4 | bed key = object address | DEAD 15.5 min, crumb "walk loc" (K2_GetActorLocation) |
| 5, 6 | pump run inside a RegisterHook callback (HUD draw, then player tick) | VOID: client hung at the first command |
| 7 | hook queues pump via ExecuteInGameThread, async loop = watchdog | 55.7 min, 326 commands, no Lua crash; ended by a GPU device hang (DXGI_ERROR_DEVICE_HUNG, stack hash 08E4D92B..., no UE4SS frames) |

Runs 1, 3, 4: same stack hash 971FE01C13691DB1C6C9089A71272A9BD43A8E38, access violation inside the UE4SS Lua VM,
at a different Lua call each time. Reading: Lua state race between the LoopAsync threads and game-thread callbacks
(unverified; supported only by run 7 lasting 2.7x longer than the longest crash time).
Verdict: Lua VM crash not seen in 55.7 min on the pump build = PARTIAL (one run; cause of the GPU hang unverified).
Rules learned: never run engine-calling code directly inside a RegisterHook callback (hang); keep Lua work out of LoopAsync threads.

Run 8 (18:22-19:23, committed build a8885f7, stress.py 60): alive, 387 commands, 60.2 min, no new crash folder, pump fed by the async watchdog once (at start). Two long runs (55.7 and 60.2 min) without the Lua VM crash; longest earlier time-to-crash 20.2 min. Cause (Lua state race) still a hypothesis.

Porter + Guard v1 (11-12, FairCrew), client gym, bot owner, mod/test/jobs_test.py:
| Row | Check | Result |
|---|---|---|
| J1 | Porter takes items from the bot owner (virtual `bothold Scrap 3`), one per 4 s within 300 uu | PASS (3 "took Scrap" lines, jobs_out2.txt 19:45-19:46) |
| J2 | Porter walks to the storage chest near its bed when the owner is within 800 uu of the bed, unloads | PASS (walked 261 + 97 uu with load; ledger `box ... Scrap=3`). Test 1 FAIL: stood still 2.5 min, aimed at the chest's floor-height origin; fixed with flat distance + pawn-height target |
| J3 | Guard at home stands on the line bed -> enemy (spawned NPC_Peccary_Sow), max 400 uu out | PASS ("crew 0 uu off post" within 6 s, follows the sow as it moves) |
| J4 | Guard clears when the enemy is gone; off duty below need 15; back on at rest 60 / fed 40 | PASS (guard clear, off duty tired rest=10, back on duty) |
| J5 | Stress with job commands (`stress.py 20 jobs`) | alive 21.5 min, 51 commands, no new crash folder (stress_out9.txt). Command count is lower than earlier runs; cause unverified |
Limits at the time of these rows (11-12): Porter bag and box were mod-side lists, no real inventory items moved, a real player could not hand items over (changed 11-13, see "Porter with real items" at the end). In J1/J2 the bot stayed within 800 uu of the bed, so items were unloaded one by one, not as a batch of 3. Guard deals no damage and does not draw the enemy's attention; whether enemies react to it is untested. Gift-picks-job mapping not built; jobs are set by the `job` test command only.

## 11-13 crew = player bodies + crew harness (client gym, agent-vs-agent)
Harness: `py -3.13 -I test/crew_harness.py [--keep]` (one client run, about 4 min for rows H1-H9, about 8 min with H10-H13; table on stdout, report C:\re\abioticfactor\crew_harness_report.md, exit 1 on any FAIL). Sets mods.txt AfPilot 1 at start, 0 at end, kills the client. Needs test commands `who` and `anim` in FairCrew.

| row | check | 17:16 run | 17:27 run |
|---|---|---|---|
| H1 | bot owner + crew spawn as player bodies with Abiotic_AI_Controller_ParentBP_C | PASS | PASS |
| H2 | random look: 9 parts set, the two bodies differ | PASS | PASS |
| H3 | our bodies are not counted as players (bodies=3 real=1) | PASS | PASS |
| H4 | recruited with a gift | PASS | PASS |
| H5 | crew follows the owner (apart < 600 uu after the walk) | PASS 339 | PASS 234 |
| H6 | walking feeds the anim blueprint (velocity and its Speed > 50) | PASS weak | PASS weak |
| H7 | moves in to the owner's bed | PASS | PASS |
| H8 | settled tired crew stays home, rest recovers | FAIL (harness order bug, fixed) | PASS r 6 -> 10 |
| H9 | client alive, no Lua errors | PASS | PASS |

H6 is weak: speed 60 / 73 uu/s seen in 1 of 12 samples (1.3 s apart); in the others velocity was 0 while the position had changed between samples. So the crew moves in short bursts or is slow; a smooth walk is unverified and needs a human look or a faster sampler. Not covered: jobs (porter, guard), enemies, damage/death of a body, saves, multiplayer (dropped by the user).

## Crew movement + parkour course (11-13)
Motion layer in FairCrew/Scripts/main.lua: gaits STROLL 190 / JOG 500 / SPRINT 685 uu/s (BaseWalkSpeed + CurrentWalkSpeed, sprint by ToggleSprint); blocked move tries Jump, then Crouch, then a launch; ladder = stock climb state, rise driven by the mod (teleport steps), exit by ToggleLadderClimbing + launch.
Course: command `parkour` (floor, hurdle y+250, bar y+550, fences, platform + Ladder_Generic_C at y+900).
Harness rows (test/crew_harness.py, about 8 min): H10 test body lane, H11 test body ladder, H12 crew member lane, H13 crew member ladder. Run 5 (crew_harness_out_mo5.txt): H1-H13 PASS.
Client GPU: env AF_ADAPTER=1 (run_route.ps1 in the project root) puts the client on the second GPU.
Known gaps: crew lane run is flaky (harness run 5 pass; video run 19:23 veered to the fence and gave up, "mo gave up d=393"); test/vid_course.py gives no usable video (camera blocked by gym props; it also left the client running and mods.txt at AfPilot : 1); how the movement looks to a human, real-map ladders: unverified.

## Porter with real items (11-13, client gym)
The porter takes real items from the owner's inventory (owner within 450 uu) and puts them into a real storage chest near its bed.
One run (log real_out2.txt, not in the repo): with a bot owner, 3 Bandage ended in the chest (slot 0 x3); with the player as owner, 7 real Bandage were taken and 6 placed (one slot each, no stacking onto existing piles; the chest was full at 8 slots).
Not tested: give-back to the owner when the chest is full (coded only). Later runs that day failed on the test bot's walking (bed not reached) and testing was paused. No harness row covers the porter with real items.
