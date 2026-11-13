# Crew jobs plan (FairCrew), 2026-11-12

Status: plan only, nothing built. Feasibility notes marked "dump" come from a name search of
dump/UE4SS_ObjectDump.txt; that a function exists does not show it is callable from Lua (unverified until a probe runs).

## Index
1. Goal and why
2. Design rules
3. The four jobs
4. How a job is given
5. Needs tie-in
6. Build order (each step with its test)
7. Risks and unknowns
8. What needs the user

## 1. Goal and why
- Persona plans (persona_plans.md, section 6): "crew have a job" is the most-raised gap, 6 of 11 personas.
- Community (opinion_missing.md, a private digest of Steam reviews, not included): jobs could touch inventory/sorting (49 negative mentions), backtracking (36),
  solo play (36), decay/repair (27), base defense (10), workers/automation (7). Not late game (95) or enemy respawn (47).
- Today a recruited crew member only follows, or stands at its bed.

## 2. Design rules
- Fair play: a job does only what a player could do by hand, at player speed or slower. No free items,
  no teleporting goods; goods move only as far as the crew member walks.
- Crew decide by rest and food: a tired or hungry crew member refuses or stops a job.
- Visible: the player can see what the crew member is doing and why it stopped (position + a short log line now;
  barks later, they are rank 2 in the persona plans).
- One job per crew member. Simple state machine, same style as the existing follow / home modes.
- Every job is testable by the bot owner in the gym, no human needed for pass/fail of the mechanics.

## 3. The four jobs
| Job | What it does | Complaint it targets | Game calls (dump, unverified) | Risk |
|---|---|---|---|---|
| Porter | Follows; owner hands it items; when the owner is back at base it walks to a storage box and unloads | inventory, backtracking | Abiotic_InventoryComponent_C: "Transfer Multiple Items to Inventory", Server_TransferItemsToCharacterByRowName | NPC may have no inventory component: fallback = mod-side list of row names + give on unload |
| Steward | Stays home; every few minutes walks box to box and sorts; later: moves raw food to the fridge | inventory / sorting | Abiotic_InventoryComponent_C:SortInventory, "Quick Move Item With Possible Stack" | low for sort, medium for moving |
| Medic | Stays home or follows; walks to a hurt owner and heals slowly, uses up one bandage from its gifts | solo play | AbioticCharacter:GetLimbHealth / SetLimbHealth, GetTotalHealth | low; SetLimbHealth takes simple values (unverified) |
| Guard | Stands at a post near the beds; on an enemy within range, moves between it and sleepers and draws its attention; does not deal damage in v1 | base defense | existing move_to; enemy list by class scan | medium: enemy target switching is unknown |

Left out of v1: repair (dump shows only player-side Request_RepairItem and widget paths), cooking and farming
(Abiotic_Item_ParentBP_C:CookItem exists, the full loop is larger).

## 4. How a job is given
- No new UI in v1. The gift item picks the job at recruit time or later:
  bandage -> Medic; food -> Steward; any container/backpack-type item -> Porter; a weapon -> Guard.
- Giving a different gift to an owned crew member changes its job. Test commands: `job <name>` in faircrew_cmd.txt.
- Later, after need barks exist: the crew member says its job on change.

## 5. Needs tie-in
- Working drains rest faster than standing (start: x1.5 Porter, x1.2 others; same numbers as the role archetypes in
  persona_plans.md). At rest or fed below QUIT_NEED (15) the job stops and the crew member goes to bed / waits for food.
- A job is refused below JOIN_REST 60 / JOIN_FED 40, same thresholds as joining.

## 6. Build order
Each step ends with a bot-owner test row in mod/TESTPLAN.md and a stress run (stress.py) before commit.
0. Precondition: crash hunt closed (pump build survives the stress runs).
1. Job frame: `m.job`, `job <name>` command, state in the status line, needs drain multiplier, stop/refuse rules.
   Test: set job, drain rest with `needs`, see stop + bed.
2. Probes (read-only, one call each, crumb before each): does a crew NPC have an inventory component; SortInventory on
   a gym storage box; GetLimbHealth on the bot. Result decides the Porter fallback.
3. Medic (smallest, verifies the write path): bot owner hurt via SetLimbHealth, crew walks over, heals in steps, one
   bandage used. Test: health before/after, bandage count.
4. Steward sort: two gym boxes with mixed items, crew walks to each, sorts. Test: item order before/after.
5. Porter: hand-over by gift while following, unload at the nearest box when the owner is within base range.
   Test: item counts owner -> crew -> box, distance walked > 0.
6. Guard: post near bed, reaction to a spawned enemy. Test: crew position between enemy and bed; enemy target (if readable).
7. Gift-picks-job mapping, README + TESTPLAN, push.

## 7. Risks and unknowns
- Any new engine call can crash the client from Lua (known: FText args, out-struct calls, GetCurrentHeldItem). Each new
  call gets a probe run first.
- Crew pathfinding is still straight-line + detours (autonav PARTIAL): jobs that walk between boxes need a base without
  obstacles in the gym; in a real base the crew may get stuck. This is the biggest practical limit.
- Co-op: ownership and box permissions not designed.
- Balance numbers are guesses until a human plays.

## 8. What needs the user
- Order of jobs if different from 3 -> 4 -> 5 -> 6.
- Whether Guard may deal damage later.
- A play session at the end: does a working crew member feel useful or in the way.

## 9. Scope steer (11-12, after a read of this plan)
Steer: do not turn the crew into a Stardew Valley / Harvest Moon cast with their own sidequests; the game has enough plot. At most a light sim: funny crew randomness while the player is there, nothing major.

Reading: no sidequests, no deep job systems. Target = light sim: small, funny, random crew behaviour that the
player sees while present at base. Consequences for this plan:
- Sections 3-6 shrink to at most the job frame + Medic + Steward sort, and only if they stay small. Porter and Guard parked.
- New first item, "idle bits": while the owner is within sight range, a homed crew member picks a random short action
  every 20-60 s: walk to a random box and look in, sit/stand at a bench or chair, face the owner and wave/emote, follow
  another crew member a few steps, stand at the fridge when fed is low, lie down early when rest is low. No effect on
  items or balance. Needs gate which bits can roll (tired crew do tired bits).
- Feasibility of emotes/animations on NarrativeNPC from Lua: unverified, needs a probe; fallback = movement-only bits.

## 10. Porter + Guard un-parked (11-12)
Decision: porter and guard could be useful, so they get built and tested too.

Reading: build Porter and Guard and test them with the bot owner, still small (section 9 scope stays: no
sidequests, nothing major). Order now: job frame -> probes (crew inventory component, enemy list) -> Porter -> Guard ->
stress run -> commit. Medic, Steward and idle bits stay as listed, after these two. Guard v1 deals no damage.
