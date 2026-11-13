# FairCrew: player-persona encounter plans (2026-11-12)
Source: 4 Sonnet agents, reasoning only from a brief of the mechanics (no play data). Scores are the agents' predictions, NOT measurements. The raw replies were not kept (extract failed); they are condensed here.

## Index
1. Score table  2. Per persona  3. Shared frictions  4. Personality archetypes (merged)  5. Proposed changes, ranked

## 1. Score table (0-10 = how well today's mechanics serve that player's own goal)
| Persona | Goal | Score | Biggest friction |
|---|---|---|---|
| Achiever / min-maxer | base output, progression | 4 | needs loop is a chore with no payoff: home crew do nothing |
| Speedrunner | next sector fast | 2 | 4 s linger + cot detour + upkeep cost time, zero speed payoff |
| Explorer | every corner, not slowed | 4 | follower is a leash (speed, pathing, forced walk home) |
| Roleplayer | NPCs feel like people | 5 | friendship number has no visible payoff; declines identical for all |
| Base builder | lived-in base | 5 | home crew stand like statues |
| Co-op socializer (4 friends) | shared moments, no "whose NPC" | 3 | single owner + one bed binding |
| Chaos / system-breaker | poke the rules | 6 | abuse has no visible consequence or memory |
| Anxious solo newcomer | safety + company, no wiki | 4 | rules invisible (gift trigger, rest/fed, cot = home) |
Mean 4.1.

## 2. Per persona (encounters -> what they try -> fix)
- Achiever: recruit with ration; cot at base; returns rest 70 fed 50 -> joins free, then only micromanages meters. Exploits: gift spam to friendship 100, rotate home/follow, crew as storage. Fix: home crew work a station near the cot, output scaled by friendship, gated by rest/fed.
- Speedrunner: skips NPC (4 s lost) or grabs it; follower lags at doors; hits <15 mid-sector and walks home. Exploit: recruit and abandon, crew as distraction. Fix: follower keeps pace, no rest drain for first N min, instant recruit by dropped gift at high friendship.
- Explorer: 4 s wait annoys; follower blocks narrow paths; walks home mid-expedition. Fix: scout role, crew at home shares map memory of rooms seen (through conversation); follower catches up when out of sight 20 s.
- Roleplayer: gift -> follow with no reaction line; "tired" reads as a rule; two crew never speak. Fix: friendship tiers unlock barks, personal requests, gossip between crew ("Mara told me Ken saw food in B2").
- Builder: crew stands by the cot in the same spot; declines punish going out. Fix: home schedule (station, eat from a player-stocked food box that feeds `fed`, sit, sleep).
- Co-op: gift race, two cots -> ambiguity; follower walks home alone mid-raid and dies. Fix: crew belongs to the team, any player's gift counts, cot choice prompt, needs shown as speech bubbles to all.
- Chaos: starve, bed theft, body-block, lead into danger, 3.9 s linger, gift spam. Fix: grudge flag (trust drops from starving/danger/bed loss) that the NPC tells others via conversation memory.
- Newcomer: walks up empty-handed, nothing happens; recruits by accident; "tired" decline reads as rejection; NPC walking home reads as a bug. Fix: barks that state the need ("I'm exhausted, got a bed?"), hint when holding an item near wild crew, ask once below 50.

## 3. Shared frictions (how many of 8 personas raised it)
- Needs/declines are invisible or unexplained: 5 (newcomer, roleplayer, co-op, chaos, builder).
- Crew at home do nothing: 3 (achiever, builder, explorer).
- Follower is slow / walks home mid-trip: 3 (speedrunner, explorer, co-op).
- No memory or consequence, friendship without payoff: 3 (roleplayer, chaos, achiever).
- Ownership is one player: 1 (co-op), but lowest score after speedrunner.

## 4. Personality archetypes (merged from 12 proposals; multipliers on existing constants)
| Name | Trait numbers | Visible behaviour | Serves |
|---|---|---|---|
| Glutton (proposed by 3 of 4 agents) | fed decay x1.5, gift fed x1.5, hungry decline at fed<55 | begs, stares at food | achiever, chaos |
| Homebody | follow rest drain x1.5, home rest regen x1.5-2, won't leave at rest<80 | sits on cot / fidgets at bench | builder |
| Stoic veteran / hauler | rest drain x0.5, friendship gain x0.6 | stands guard, never complains until it stops at 15 | speedrunner, explorer |
| Night owl | follow rest drain x0.6, home regen x0.5 | paces at night, slow in the morning | roleplayer |
| Loyalist | friendship from time x2, tired decline at rest<40 | follows closest, guards sleepers | newcomer, co-op |
| Loner scout | friendship gain x0.5, decline thresholds -20 | peeks into rooms, shares map only with trusted crew | explorer |

## 5. Proposed changes, ranked by personas helped per unit of work (my ranking, unverified by play)
1. Need barks: crew say why they decline and ask once below 50 (text over head, no FText from Lua: needs a safe display path). Helps 5.
2. Per-NPC personality: 2 multipliers + 1 behaviour from table 4, rolled at spawn. Helps all; cheap (constants already exist).
3. Grudge + gossip on the planned conversation-shared memory. Helps roleplayer, chaos, explorer.
4. Home routine + food box that feeds `fed`. Helps builder, achiever.
5. Team ownership in co-op. Helps co-op; untestable without several players.
6. Follower catch-up when out of sight. Helps speedrunner, explorer; depends on the nav problem still open.

## 6. Playstyle roles (added 11-12 for the question whether these are player personas like builder or fighter; 1 Sonnet agent, predictions not measurements)
| Role | Goal | Score | Biggest friction | Fix |
|---|---|---|---|---|
| Fighter | combat, allies that matter in a fight | 2 | crew do not fight: liability only; walks home mid-sweep | friendship >= 50 unlocks support: decoy (draws aggro) or throws heal/ammo, costs extra rest |
| Crafter / cook / farmer | production chains, supply | 3 | crew eat stock, produce nothing, no work verb | "home post": crew at home with rest >= 60 and fed >= 40 tends one adjacent station slowly, output into a box |
| Hoarder / looter | carry everything home | 1 | no carry | pack slots 4-12 by friendship; on walk-home they haul the pack to the home chest |
Mean of the 3 roles 2.0; all 11 personas 3.5.

Role archetypes: Porter (follow rest drain x1.5, friendship gain x1.2; bulging backpack, trudges home when full); Medic-Guard (fed drain x1.3, join threshold -10; steps in front at fights, heals at low health); Steward (home rest regen x1.5, fed drain x0.7; tends cooker/plots, waves when output is ready).

Effect on the ranking in section 5: "crew have a job" (home post / carry / support) is now the most-raised gap: 6 of 11 personas (achiever, builder, explorer, fighter, crafter, hoarder). It moves to rank 1, need barks to rank 2.
