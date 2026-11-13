# Abiotic Factor AI-MAP (UE 5.4, all-Blueprint)

Static read of the game's AI Blueprints, dated 2026-11-06 (game build id not recorded; later patches may differ). Sources: a local JSON export of the game's Blueprint assets and a UE4SS object dump. Neither is in this repo, so the `assets\`, `scratch\` and `dump\` paths, line numbers and "stmt" numbers below point at local files. "Cheat" is used in the usual game-AI sense: the AI acts on information its senses did not give it (the game's own property is named `LastSawTargetCheatDuration`). Section 6 is the hook plan written before the mods; section 8 is the one in-game check.

## Index (section: line range)
- 0. Citation convention: lines 18-22
- 1. Architecture: lines 23-44
- 2. Perception: lines 45-93
- 3. Key tasks / services: lines 94-101
- 4. Spawning / director: lines 102-110
- 5. CHEATING verdict: lines 111-138
- 6. Mod hooks (UE4SS Lua; paths verified in dump): lines 139-157
- 7. Gaps: lines 158-161
- 8. Verified in game (2026-11-06): lines 162-163



## 0. Citation convention
- Cites: `BP/<path>.json:<line>` or `obj <ObjectDump path>`. The shipped exports in `assets\` have NO bytecode. Bytecode cites refer to the re-export `scratch\assets_bc\AbioticFactor\Content\Blueprints\<path>.json` (built by scratch\afexport2, ReadScriptData=true), as "stmt N" = top-level ScriptBytecode index inside the named function (use scratch\fsum.py / si.sh; local helper scripts, not in this repo). Stmt numbers are pointers into that local re-export; only C1's were re-checked for this copy.
- Paths below are relative to `Content\Blueprints\`. Dump = `dump\UE4SS_ObjectDump.txt`.
- Property defaults (CDO) cites are line numbers in `assets\...json`.

## 1. Architecture
- Chain: `Characters/NPCs/AI_Controller_NPC_<X>` (~70, parent `Characters/NPCs/Abiotic_AI_Controller_ParentBP`) runs `AI/<X>/BT_Main_<X>` (+`BT_Attack_<X>`), which calls shared subtrees/tasks in `AI/Common` (115 files: BB_Main, BTD_*, BTS_*, BTT_*, BT_Alert*, BT_Follower, BT_Pet, BT_Patrol, BT_Flee, BT_FindCover, BT_FindCombatCoverLocation, BT_FindAntiCoverLocation, BT_Find*Teleport/Jetpack/Shield*). 37 subfolders under `AI/`.
- Pawn: `Characters/NPCs/NPC_Base_ParentBP` (all NPCs). Perception comps live on the pawn (`AIPerception_GEN_VARIABLE`), not the controller.
- Controller loop: timer `DecisionTick` (in `ExecuteUbergraph_Abiotic_AI_Controller_ParentBP`) -> `DecayAttackerList`, `ProcessPerceptionList`, `CheckCombatTargetValidity`, `GetHostilityTowardsTarget`, `GetSpottablePoints` -> `CheckLineOfSightToLocations(target,2)`, `UpdateBehaviorTreeValues`, `CheckForCombatBuffs`, `SetCurrentCombatTarget`, `DoActionToSensedTarget`.
- Boss allies: `AI/BossAlly/` BT_BossAlly, _Kylie, _Mage, _Sniper, BTD/BTT_BossAlly_*.
- Squad: `BP_SquadManager`, controller fns `AlertSquadToCombat`, `GetSquadMemberAI`, `CheckIfSquadAlreadyInCombat`.

### 1.1 Blackboard `AI/Common/BB_Main.json`
| Key | Type |
|---|---|
| SelfActor, TargetActor, AllyTarget, PatrolPath | Object |
| TargetLocation, LastKnownLocation, LastStuckLocation | Vector |
| PotentialCombatTargetCount, PatrolPathIndex, FailedHits, MeleeCounter | Int |
| LastStuckTimestamp, LastSawTargetTime, RangeToMeleeAttack | Float |
| RecentlyTakenDamage, TargetLocked, AbilityOnCooldown, HasHeardSound, CanSeeTarget, Stunned, CombatMode, DBNO | Bool |
| AwarenessState | Enum |

### 1.2 EQS (`Blueprints/EQS/`, dump)
- Location queries: EQ_FindCoverLocation, _AntiCover, _CombatLocation(_Support), _CloseCombat, _CombatHide, _Hidden, _Escape, _ExorCombat, _ShieldCombat, _TeleportCombat, _TeleportClose(Follow), _Jetpack*, _Mirage, _Leyak, _SnowmanTeleport, _CombatWander, EQ_TetheredRunFromTarget.
- Contexts: EQ_TargetContext_Players, _Allies, _NPCCurrentTarget, _NPCFollowTarget, _LastKnownLocation, _ReservedLocations, _NPCTetherVolume, _OwningMage.
- Spawn queries: EQ_FindClosestSpawnLocation, EQ_FindAssaultSpawn, EQ_FindCloseEntitySpawnLocation, EQ_FindTraderSpawn.

## 2. Perception
Custom layer over UE AIPerception. Senses: Sight + Hearing (`AISenseConfig_Sight_1`, `AISenseConfig_Hearing_0` under `NPC_Base_ParentBP_C:AIPerception_GEN_VARIABLE`, dump).
- Defaults `Characters/NPCs/NPC_Base_ParentBP.json:117`: sight 2000, lose 3000, peripheral 85, max age 60; hearing 750, max age 1; detect neutrals+friendlies. No LoS-hearing/AutoSuccessRange set anywhere -> hearing ignores walls (UE default).
- Reach to BB:
  - Sight: `ProcessPerceptionList` polls `GetCurrentlyPerceivedActors(AISense_Sight)`, keeps `ListOfPerceptionTargets`, `LastSeenPotentialCombatTargetsList`, `AttackerList`. `IncreasePotentialTargetPerceptionValue` builds a detection meter from `Eyesight`, `LastKnownDifficulty`, `IgnoreLightLevel` (light dependent = fair). `CheckLineOfSightToLocations` = LineTraceSingle from `GetCharacterEyesLocation` to target spottable points (fair LOS gate). `CheckForBestTargetOnPerceptionList` scores distance + AttackerList damage + stat `TargetPriority_Multiply`.
  - Hearing: `NPC_Base_ParentBP.Server_HeardSound` (stub .json:192915, stmt 35280) -> controller `HeardNewSound` -> `AI/Common/BT_HeardNewSound` (HasHeardSound, distance, facing dot test, turret check) -> `BT_SetLastKnownLocation`, `AddOrUpdatePotentialTarget`, `TurnToFaceDirection`.
  - BB writers: `BT_ChooseBestTarget` (LastKnownLocation, LastSawTargetTime, CanSeeTarget, HasHeardSound, TargetLocked); `BT_SetCombatState` (CombatMode + `PerformCombatAlert`); `BT_SetLastKnownLocation`.
  - GAP: `BndEvt__..PerceptionUpdatedDelegate` on NPC_Base_ParentBP (stub .json:10393, ubergraph 31313) body unresolved; do not assume OnTargetPerceptionUpdated drives BB.
- Noise emitters seen: `AISense_Hearing.ReportNoiseEvent` in `PerformCombatAlert` (Coworker/Pillager/Zombie controllers also loop all `NPC_Zombie_C`), `ReceiveHit` (touch, loud 1, range 100), `NPC_Monster_Carbuncle.OnRep_TetherTarget`, `NPC_PlayerDecoyHologram`. Player footstep/weapon noise: outside export (gap).

### 2.1 Per-NPC table (class suffix; "." = inherits Base/UE default; OFF = bStartsEnabled false; last col = sight object line in `Characters/NPCs/NPC_<class>.json`)
| NPC | Sight | Lose | Periph | MaxAge | Hear | HearAge | line |
|---|---|---|---|---|---|---|---|
| NPCGroupe_Mountaineer | 4000 | 5000 | . | .  | . | .  | 59 |
| Base_ParentBP | 2000 | 3000 | 85 | 60  | 750 | 1  | 117 |
| Boss_Tentacle | . | . | . | . OFF | . | . OFF | 117 |
| Boxy | 1000 | 3500 | 80 | .  | 500 | .  | 128 |
| Coworker | 1000 | 3500 | 80 | .  | 500 | .  | 121 |
| FlameRat | . | 2500 | . | .  | 500 | .  | 117 |
| Groupe_Shield | 4000 | 5000 | . | .  | . | .  | 66 |
| Interfector | . | 2500 | . | .  | . | .  | 98 |
| LabRat | . | 2500 | . | .  | . | .  | 111 |
| LabRat_Garage | . | 2500 | . | .  | . | .  | 107 |
| Monster_BogMan | 3500 | 5000 | 90 | .  | 1200 | .  | 142 |
| Monster_Carbuncle | . | . | . | . OFF | . | . OFF | 118 |
| Monster_Composer | . | . | . | .  | . | . OFF | 118 |
| Monster_Exor_Armored | 3750 | 5000 | . | .  | . | .  | 77 |
| Monster_Mgt_Larva | 800 | 1200 | 70 | .  | 400 | .  | 112 |
| Monster_Mgt_LarvaBig | 800 | 1200 | 70 | .  | 400 | .  | 112 |
| Monster_Peccary | 1600 | 2750 | . | .  | . | .  | 89 |
| Monster_Pest | 800 | 1200 | 70 | .  | 400 | .  | 88 |
| Monster_Pest_Leyak | 2000 | 3000 | 85 | .  | 750 | .  | 88 |
| Monster_Reaper | 1000 | . | 80 | .  | . | .  | 151 |
| Monster_ReaperScout | 1000 | . | 80 | .  | . | .  | 145 |
| Monster_Symphonist | 1 | 2 | . | . OFF | . | .  | 124 |
| Monster_WinterSprite | 800 | . | . | .  | . | .  | 83 |
| OrderGrunt_Trooper | 4000 | 5000 | . | .  | . | .  | 59 |
| Pillager_Musketeer | 3000 | 3500 | . | .  | . | .  | 63 |
| Pillager_Musketeer_Guard | 100 | . | . | .  | . | .  | 59 |
| Pillager_ParentBP | . | 2500 | . | .  | . | .  | 119 |
| Pillager_Preacher | 1000 | 3000 | . | .  | . | .  | 63 |
| Robot_Defense | 5000 | 8000 | . | .  | . | .  | 92 |
| Sapper | 3000 | 3500 | 80 | .  | . | .  | 80 |
| Skink_Basic | 2000 | 3000 | 85 | .  | 750 | .  | 110 |
| Soldier_Grunt | . | 2500 | . | .  | . | .  | 94 |
| Soldier_Grunt_Shotgun | . | . | . | .  | 500 | .  | 62 |
| Soldier_Grunt_Sniper | 20000 | 25000 | 60 | .  | . | .  | 59 |
| Zombie | 1000 | 3500 | 80 | .  | 500 | .  | 122 |

## 3. Key tasks / services
- Target selection: `BT_ChooseBestTarget` (BTS wrapper), controller `CheckForBestTargetOnPerceptionList`, `SetCurrentCombatTarget`, `GetHostilityTowardsTarget`; damage aggro `AttackerList` + `DecayAttackerList` (independent of senses; justified: being shot reveals the shooter).
- Last-known tracking: `AI/Common/BTS_UpdateLastKnownLocation` (ReceiveTick, dump) -> controller `BT_UpdateLastKnownLocation` (CHEAT C1).
- Alert/search: `PerformCombatAlert` (noise event to allies), `BT_HeardNewSound`, `BT_Alert*`, `BTD_IsSoundOutOfSight`, `BTD_IsSoundInTetherLocation`, `AlertSquadToCombat`.
- Cover/flee: `BT_FindCover`, `BT_FindCombatCoverLocation`, `BT_FindAntiCoverLocation`, `BT_Flee` + EQ_FindEscape/Hidden/Cover (section 1.2).
- Followers/pets/allies: `AI/Common/BT_Follower`, `BT_Pet`, `EQ_TargetContext_NPCFollowTarget`, BB `AllyTarget`; `AI/BossAlly/BT_BossAlly*` + `EQ_TargetContext_OwningMage`. No perception cheat found in companions; bodies not read in detail (gap).
- Patrol: `BT_Patrol` (`PatrolPath`, `PatrolPathIndex`), `AI_PatrolPath_DarkwaterBeast`.

## 4. Spawning / director
Director actor `Environment/Systems/Abiotic_AIDirector` (always relevant; dump `/Game/Blueprints/Environment/Systems/Abiotic_AIDirector.Abiotic_AIDirector_C`). Cites = `assets_bc/.../Abiotic_AIDirector.json`.
- CDO: `NPCCap` 120 (:16), `TimeBeforeAssaults` 90 (:93), `MaxAssaultPortals` 3 (:97), `AssaultMaxTimeLimitSeconds` 300.0 (:127). Assault data defaults: prep 20 s, spawn interval wave1/2/3/boss = 8/6/4/10 s.
- Timers (`ExecuteUbergraph_Abiotic_AIDirector`, stmt): `Tick_PrioritySpawns` 0.33 s (782), `Tick_DormantSpawns` (971), `Tick_QuickSpawns` 0.1 s (1123), `Tick_ModerateSpawns` 0.25 s (1227), `Tick_SlowSpawns` 0.25 s (1331), `Assault_Timer` 15 s (1496), `AnomalyTimer` 300 s (2128); DayNightManager hooks `AssaultCheckTime` (2064) and `HourChanged` (2295).
- Assault gates: `CheckForAssaultRestrictedHours`, `CheckDaysSinceLastAssault`, `CheckForAssaultWorldFlag`, `AssaultsEnabled`, `CheckForBenchesNearby`, `FindLoadedPlayerBases` (tag `PlayerBaseTarget`), `BeginAssault`, `ActiveAssaultTick`, `ChangeAssaultPhase`, `EndAssault`; portal cap `CurrentAssaultPortals >= MaxAssaultPortals` (stmt 10188, 10716). Inhibitors: `Deployed_Spawn_Inhibitor_ParentBP`, `BenchUpgrade_PortalSupressionField`; `AssaultPortal_BP`.
- Per-spawner `Environment/Spawns/Abiotic_NPCSpawn_ParentBP.json`: `PlayerWithinDistanceToSpawn` 7500 (:22), `SpawnCooldown_Default` 420 s (:21), `SpawnCooldownDays_Default` 2 (:20), `UseDaysCooldown` true (:19); `AntiSpawnRadius`, `MaxSpawnsPerTick` exist (values unread). Tables `DataTables/DT_NPCSpawns`, `DT_NPCSpawnSubstitutes`, enum `Data/E_NPCSpawnResponse`.
- Specialist directors (components): Leyak (`LeyakCooldown`, `LeyakTauntCooldownMultiplier`, `ActiveLeyak`), Krasue, Coworker (`CoworkerTimer`), Boxy (`BoxyTimer`, `BoxySpawnFrequency[_Encumbered]`), Reaper (`ActiveDynamicReaper`), PowerLeeches, Salem, Nyth, NarrativeNPC, StalkingNpc, Encounter, ShadowBoss. Not read in detail (gap).
- Pacing inputs found: day/hour, days since assault, world flags, bench/base presence, sandbox options (`GetSandboxOption_Int`), distance to player. No player stress/health/fear variable in the director (0 name hits), so pacing is time/place based, not stress-adaptive. Spawn freeze: `FrozenByDirector` (re-export `Environment/Systems/Abiotic_AIDirector.json`:65710), `DebugDisableNPCFreezing`.

## 5. CHEATING verdict
Overall: perception is largely honest (LoS trace, light-level meter, cone, radii). Cheating = one tuned knob (C1), scripted stalker/boss scans, and hearing through walls (C5). Verdict: MAJOR for long-duration NPCs, MINOR elsewhere.

### C1. Post-LoS live location tracking (MAJOR; partly gameplay-justified)
- Asset `Characters/NPCs/Abiotic_AI_Controller_ParentBP.json`, fn `BT_UpdateLastKnownLocation` (bytecode offsets about 1298-1721 in the re-export; the compare result is assigned at `StatementIndex` 1487, its `JumpIfNot` is at 1525), driven by `AI/Common/BTS_UpdateLastKnownLocation`.
- Bytecode: reads BB `LastSawTargetTime`; `GreaterEqual(LastSawTargetTime + LastSawTargetCheatDuration, GetGameTimeInSeconds)`; `JumpIfNot ->1721`; if true -> `GetCurrentCombatTarget.K2_GetActorLocation` -> `BT_SetLastKnownLocation`. Live position through walls for N s after sight lost.
- Property `LastSawTargetCheatDuration` (DoubleProperty, offset 0x6F8; dump `...Abiotic_AI_Controller_ParentBP_C:LastSawTargetCheatDuration`); parent default 2.0 (`Abiotic_AI_Controller_ParentBP.json:58`, decl :1353).
- Overrides (`Characters/NPCs/AI_Controller_NPC_<X>.json`, lines 17-29): BogMan, Boss_Shadow, Boss_Tentacle, Snowman, Tarasque = 120 s; Robot_Defense 60; Composer, Symphonist 20; GKHeavy 10; Robot_Corrupt 8; FlameRat, Soldier_Grunt_Shotgun 6; Boxy, Coworker, Zombie = 999999 (permanent).
- Severity: 999999/120/60 major; 20 moderate; 2-10 minor. Justified for unstoppable horror monsters (BogMan, Shadow boss, zombie horde); breaks stealth fairness.

### C2. Leyak target scan (MINOR, justified)
- `Characters/NPCs/AI_Controller_Leyak.json` fn `UpdateValidTargets` (stmt 487 GetAllActorsOfClass NPC_Base_ParentBP; 878 GetAllActorsOfClass Abiotic_PlayerCharacter): scans all players, gated by `LeyakAggroRange` (566, 998, 1094), `Character.LeyakTaunt` (761, 907), `Buff.Cryobed` immunity (272, 1772), `MaxLeyakChaseDistance[_Aggrod]` (1954). Range-gated scripted stalker. Visibility: `NPC_Leyak.UpdateLeyakVisibility` (NPC_Leyak.json:631).

### C3. Snowman alert (MINOR, justified)
- `Characters/NPCs/NPC_Snowman.json` `AlertNPCToNearbyPlayers` (stmt 120 GetAllActorsOfClass players; 363 distance test; 502 `UpdateTargetSpottedValue`): range-gated detection bump, no LoS. `ConcussNearbyPlayers` (:11097) AoE.

### C4. Zone/AoE all-player queries (none/minor)
- `AI_Controller_DarkwaterBeast.GetPlayersInWater` (:13044): only players with `Character.DarkWaterZone` (fair).
- `NPC_Monster_Composer|Tarasque|ShadowBossHand.ConcussNearbyPlayers`, `NPC_Monster_Exor_Armored.ApplyRoarDebuff` (:491): AoE effects, no targeting. `NPC_Pillager_Preacher_NiketasBOSS` ubergraph :816 (all PlayerControllers; scripted boss, unreviewed).
- `AI/LabRat/BTD_FarEnoughFromPlayers` (:251): distance condition, fair.

### C5. Hearing through walls (MINOR)
- `bUseLoSHearing` is not set in any game asset (the engine property exists, dump :36189): sound heard through walls at 750 (Base), 1200 (BogMan). `BTD_IsSoundOutOfSight` exists as possible mitigation (usage unverified).

### Not cheats (verified benign)
- `GetPlayerPawn` in Pest, Skink_Basic, Larva(_Big): client FX. `NPC_Base_ParentBP` `GetAbioticPlayerCharacter` stmts ~35388-35479: subtitle distance. Carbuncle `OnRep_TetherTarget`: PlaySound2D. `Tick_DebugVis`: debug. Most `GetActorOfClass` hits fetch `Abiotic_AIDirector_C`/`DayNightManager_C`.
- Unreviewed teleport/door (`K2_SetActorLocationAndRotation`): Boss_Shadow (:9705), Exor_Monk/Pikeman, BogMan, Composer `PerformDoorEnter/Reach`, Thespian, Yeti, Snowman, Pest_Leyak `K2_TeleportTo` (:8085). Likely traversal.

## 6. Mod hooks (UE4SS Lua; paths verified in dump)
Note: this section is the hook plan written before the mods. Current state (../README.md): FairSight does 6a.1 with a cap of 2.0 s, not the 4.0 sketched below, and nothing of 6a.2-6a.5 (never implemented); FairDirector is the mod for 6c and is unverified in a world; FairCrew took a different route from 6b (its crew are player-character bodies, ../FairCrew/README.md).
Controller parent path prefix `CP = /Game/Blueprints/Characters/NPCs/Abiotic_AI_Controller_ParentBP.Abiotic_AI_Controller_ParentBP_C`. BP hooks need the class loaded: register after world load (e.g. from a `NotifyOnNewObject` on CP) or on first `ClientRestart`.

### 6a. Fair perception
1. Cap wallhack: set `LastSawTargetCheatDuration` on every live controller: `for _,c in ipairs(FindAllOf("Abiotic_AI_Controller_ParentBP_C") or {}) do if c.LastSawTargetCheatDuration > 10 then c.LastSawTargetCheatDuration = 4.0 end end`; re-run on `NotifyOnNewObject(CP, fn)`. Also patch CDOs `Default__AI_Controller_NPC_<X>_C` for the 999999/120 classes.
2. `RegisterHook(CP..":BT_UpdateLastKnownLocation", pre, post)`: in post, if BB `CanSeeTarget` false and now - `LastSawTargetTime` > grace, restore the previous `LastKnownLocation`.
3. `RegisterHook(CP..":HeardNewSound", pre)` and `/Game/Blueprints/Characters/NPCs/NPC_Base_ParentBP.NPC_Base_ParentBP_C:Server_HeardSound`: drop the sound if a line trace NPC->sound origin is blocked.
4. Sense radii: `FindAllOf("AISenseConfig_Sight")` / `"AISenseConfig_Hearing"` -> `SightRadius`, `LoseSightRadius`, `PeripheralVisionAngleDegrees`, `HearingRange`, `MaxAge`. Defaults at `/Game/Blueprints/Characters/NPCs/NPC_Base_ParentBP.NPC_Base_ParentBP_C:AIPerception_GEN_VARIABLE.AISenseConfig_Sight_1` and `.AISenseConfig_Hearing_0`; apply with `AIPerception:RequestStimuliListenerUpdate()`.
5. Probes: `CP:ProcessPerceptionList`, `CP:CheckLineOfSightToLocations`, `CP:IncreasePotentialTargetPerceptionValue`, `CP:CheckForBestTargetOnPerceptionList`, `CP:PerformCombatAlert` (log args to validate).

### 6b. Companion behaviour
- Tasks `/Game/Blueprints/AI/Common/BT_Follower`, `BT_Pet`; drive via BB keys `AllyTarget`, `CombatMode`, `TargetActor` (`Controller:GetBlackboardComponent():SetValueAsObject("AllyTarget", pawn)`); EQS `EQ_TargetContext_NPCFollowTarget`, `EQ_FindTeleportCloseFollowLocation`. Fairness rule: companions keep same LoS/sight limits, `LastSawTargetCheatDuration` <= 4.
- BossAlly: `/Game/Blueprints/AI/BossAlly/BT_BossAlly*`, `BTD/BTT_BossAlly_*`, `EQ_TargetContext_OwningMage`.

### 6c. Director-side balancing by player stress
- No stress input exists: compute in Lua per player (health fraction, recent damage, enemies within N uu, BB `PotentialCombatTargetCount`, DBNO).
- Actuators: `FindFirstOf("Abiotic_AIDirector_C")` properties `NPCCap` 120, `MaxAssaultPortals` 3, `AssaultMaxTimeLimitSeconds` 300, `TimeBeforeAssaults` 90; hooks `/Game/Blueprints/Environment/Systems/Abiotic_AIDirector.Abiotic_AIDirector_C:BeginAssault` (delay when stress high), `:ActiveAssaultTick`, `:ChangeAssaultPhase`, `:EndAssault`; spawners `Abiotic_NPCSpawn_ParentBP_C` `SpawnCooldown_Default`, `PlayerWithinDistanceToSpawn`. Rule: director buffs tension, never the AI's senses.

## 7. Gaps
- Original `assets\` exports lack bytecode; bytecode work done on scratch\assets_bc re-export.
- `PerceptionUpdatedDelegate` body unresolved; player noise emitters outside export; Krasue/UnseenEntity/Niketas/ShadowBossHand/PowerLeech/Symphonist and teleport fns unreviewed; companion BT bodies and specialist director components unread; AntiSpawnRadius/MaxSpawnsPerTick values unread; of the Lua hooks only 6a.1 has been run in game (section 8).

## 8. Verified in game (2026-11-06)
- FairSight v0.1 (`../FairSight/Scripts/main.lua`): headless Facility_Labs + spawned NPC_Zombie -> log `clamp AI_Controller_NPC_Zombie_C 999999 -> 2.0`, readback 2.0; `NotifyOnNewObject` on `Abiotic_AI_Controller_ParentBP_C` registers once the class is loaded. Hook 6a.1 confirmed working in that one run (the log file is local, not in this repo); 6a.2-6a.5 were never implemented. For 6b and 6c see the note at the top of section 6.
