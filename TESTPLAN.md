# Test plan: FairCrew v0.2 + FairFps v0.1 (single player / host)

Restart the game first: mods load at game start. Logs: `C:/re/abioticfactor/faircrew_log.txt`, `C:/re/abioticfactor/fairfps_log.txt`.

| # | Do | Expect | Log line |
|---|---|---|---|
| 1 | Load a save | FPS number + frame-time graph on screen | `toggle true ok=true` |
| 2 | Press F8 twice | graph off, then on | two `toggle` lines |
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
