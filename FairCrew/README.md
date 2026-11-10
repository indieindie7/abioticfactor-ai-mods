# FairCrew v0.1 (Abiotic Factor, UE4SS Lua)

Random stranded scientists appear around the facility. Stand next to one for 4 seconds and they join you.

- Up to 3 in the world, 2 following each player. A new one spawns every 10 min while under the cap, at an NPC spawner (or navmesh point) at least 25 m from every player, never in view-popping range.
- Idle: they wander around their home spot (Animal Crossing villager style).
- Following: they walk after you. Friendship grows while you stay together and drains while you leave them more than 30 m behind; at 0 they walk home and can be recruited again (Core Keeper villager / AC move-out style).
- They use the game's own ally pawns (NarrativeNPC_BossAlly, _Heavy, _Sniper) and their stock combat behaviour tree. No buffs, no teleporting; FairSight caps their wall-tracking like every other AI.

Log: `C:/re/abioticfactor/faircrew_log.txt`.

## Verified (11-09, dedicated server, headless)
- Spawn works, the stock ally controller possesses the pawn (`AI_Controller_NPC_BossAlly_C`), recruit triggers, friendship ticks.
- NOT verified: walking (wander/follow). With no player connected the server has no navmesh (random-point query returns no hit), so movement needs a real player test. Not verified either: how hostile NPCs treat them, and whether they survive a save/reload (they are not saved; new ones spawn).
