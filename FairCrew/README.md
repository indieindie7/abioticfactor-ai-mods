# FairCrew v0.2 (Abiotic Factor, UE4SS Lua), state 2026-11-13

Random stranded scientists appear around the facility. Hold a food or healing item (any of 271 rows: food, bandages, medkits; list in Scripts/gifts.lua) next to one for 4 seconds: they take one and join you.

- Bodies: each scientist is a player character (`Abiotic_PlayerCharacter_C` with the stock AI controller) with a random look: 9 parts (head, hair style, hair colour, head accessory, upper body, lower body, shirt colour, shoes, tie) picked from the game's own customization tables. They are not counted as players. Before 11-13 the mod used the game's NarrativeNPC ally pawns.
- Up to 3 in the world, 2 following each player. A new one spawns every 10 min while under the cap.
- Idle: they wander around their home spot (Animal Crossing villager style).
- Following: they walk after you. Friendship grows while you stay together and drains while you leave them more than 30 m behind; at 0 they walk home and can be recruited again.
- Beds: lead a follower to a free bed you built (crafted beds, cots, mattresses, sleeping bags) and stand by it 3 s. They move in and stay around it (4 m).
- Needs: each scientist has rest and fed, 0 to 100. Rest recovers at home near the own bed and drains while following; fed drains all the time; a gift feeds them. A settled scientist joins you only when rested (60) and fed (40); a tired or hungry one says no, and a follower whose rest or fed drops below 15 walks home.
- Jobs: porter (takes items from the owner, carries up to 12, unloads into a storage chest near its bed) and guard (stands between its bed and an enemy, at most 4 m out; goes off duty when tired or hungry). Jobs are set with the test command `job` only; there is no in-game menu.
- Movement: three gaits (stroll 190, jog 500, sprint 685 uu/s). A blocked move tries a jump, then a crouch, then a launch. Ladder: the body enters the game's own climb state and the mod raises it in small teleport steps.
- Fair play: no stat buffs and no player-only powers; FairSight caps their wall-tracking like every other AI. The mod sets a crew body's position directly in two places only: the ladder rise, and once at spawn when the body comes up more than 500 uu from its spot. Test commands can also move bodies.

Log: `C:/re/abioticfactor/faircrew_log.txt`. Test commands are read from `C:/re/abioticfactor/faircrew_cmd.txt`.

## Tested (scripts only, agent vs agent in a test gym; details in ../TESTPLAN.md)
- Crew harness `test/crew_harness.py`, 2026-11-13: rows H1-H13 all PASS in one run (spawn as player bodies, random look, recruit, follow, walk state, move in, needs, obstacle lane, ladder, no Lua errors). Report: ../docs/crew_harness_report.md. The walk row (H6) saw the follower moving in 4 of 12 samples; two earlier runs were weak (speed 60 and 73 uu/s, seen in 1 of 12 samples), so a smooth walk is unverified.
- Needs rows (11-11) and job rows J1-J4 (11-12): PASS, with a bot as the owner.
- Porter with real chest items (11-13), one run: a bot owner's 3 items ended in the chest; with the player as owner 7 were taken and 6 placed (chest full). Give-back on a full chest is coded, not tested. Testing was paused after that.
- `tools\selftest.ps1` on a hidden dedicated server, 2026-11-10: 12/12 pass, 1 SKIP, 1 INFO. That run predates the player bodies.

## Not verified
- The obstacle lane with a crew member is flaky: 1 pass, 1 fail (veered to the fence and gave up).
- Ladders on real maps (only the gym ladder was tried).
- How the movement looks to a person; there is no usable video.
- Pathfinding: engine path requests fail for these bodies, so they walk by direct moves plus a simple detour walker.
- How enemies treat the crew, damage and death, save and reload (crew are not saved; new ones spawn).
- A client Lua VM crash seen in long runs on 11-12 has not come back in two later long runs; the cause is not proven fixed.
