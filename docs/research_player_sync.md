# How a player is synced and drawn in multiplayer (Abiotic Factor, UE 5.4.4)

2026-11-13. Evidence labels: **[dump]** = seen in dump/UE4SS_ObjectDump.txt; **[engine]** = how stock Unreal 5.4 works, from general engine knowledge, not checked inside this game; **[unverified]** = not tested.

## Index
1. Short answer: server sends values, each PC animates locally (lines 13-15)
2. Position: how it travels [engine]: prediction for you, smoothing for others (lines 16-21)
3. Animation: how it is drawn: anim blueprint reads character values (lines 22-28)
4. State and looks: what the server pushes [dump]: OnRep variables, RPC counts, customization rows (lines 29-37)
5. What this means for our crew bodies: host-only proof, server spawn needed (lines 38-44)
6. Tests to run (dedicated-server harness): six server-harness checks (lines 45-52)

## 1. Short answer
The server owns the truth. It does not send animation. It sends a few small values per character (where it is, how fast it moves, which way it looks, a handful of state flags, which clothes rows it wears). Each player's own PC then runs the animation blueprint locally and builds the pose from those values. So two players never see the exact same frame of animation, only the same position and the same state.

## 2. Position: how it travels [engine]
- **Your own character:** your PC moves it at once (prediction), and sends each move to the server (input + timestamp). The server replays the move, and if its result differs it sends a correction and your PC rewinds and replays. This lives in CharacterMovementComponent.
- **Other players on your screen ("simulated proxies"):** the server sends each one's ReplicatedMovement (location, rotation, velocity) some times per second, less often when far or not relevant. Your PC moves the collision capsule to the new spot and slides the visible mesh toward it over a few frames (mesh smoothing), and extrapolates with the velocity between updates. That is why a laggy player glides or snaps.
- **AI characters on the server:** no prediction. The server moves them (AI controller + path following); every client sees them as simulated proxies, same as other players.
- Only actors the server marks as replicated and relevant reach a client. An actor spawned on one client only exists on that client.

## 3. Animation: how it is drawn
- [engine] No bone poses go over the network. The animation blueprint runs on every machine and reads values off the character each frame.
- [dump] The third-person body uses `ABF_Scientist_AnimBP_C` (dump line 177838). Its variables show what it reads: Speed, Direction, IsFalling, IsCrouching, IsSprinting, Yaw, Pitch, LookAtLocation, TurnInPlace, Is DBNO, Is Dead, Is Sleeping, IsSittingInSeat, IsUsingTerminal, InteractState, Unarmed, HasShield, ShieldBlocking, MovingCart, Grabbed, RecentlyPunched, RecentlyUsedItem, SpeakingAlpha, VOIPAlpha, PlayerVoiceActor, IDCardAlpha.
- [dump] It holds a `PlayerCharacter` reference, so it pulls these from the character, not from the network directly.
- [dump] Other animation classes: `HumanPostProcess_AnimBP_C` (131181), first-person `FPArms_AnimBP_C` (174969) and `FPLegs_AnimBP_C` (190863): you see your own arms/legs; others see the scientist body.
- [engine] Walk/run comes free: Speed and Direction are computed from the replicated velocity. One-off actions (attack, emote, use item) come from a replicated variable changing or a remote call.

## 4. State and looks: what the server pushes [dump]
`Abiotic_PlayerCharacter_C` function counts: Server_ 30, Client_ 31, OnRep_ 35, Multicast_ 0, Local_ 34.
- **OnRep_ (35)** = "a replicated variable changed, react". This is the game's main sync channel. Examples: OnRep_CurrentWalkSpeed, OnRep_CurrentJumpHeight, OnRep_CurrentPerformingEmote, OnRep_InteractAnimationState, OnRep_ItemInHand_BP, OnRep_Gear_*BP, OnRep_Flashlight_On, OnRep_SensedByAI, OnRep_OverheadName. Native parent `AbioticCharacter` (39553): OnRep_IsSprinting, OnRep_IsAiming, OnRep_CurrentHealth, OnRep_CurrentStamina, OnRep_MaxStamina, OnRep_StatModifiers, OnRep_GhostMode.
- **Multicast_ 0**: the blueprint has no "tell everyone now" calls by that name. Events reach other players through variables (OnRep), which also works for players who join later.
- **Server_ (30)** = client asks the server to do something. **Client_ (31)** = server tells only the owning player (Client_TakeDamage, Client_ApplyForce, Client_ToggleSleepState, Client_ToggleDBNOState, Client_ThirdPersonView, Client_TeleportFX, UI messages). An AI-owned body has no owning player, so these go nowhere for it [engine].
- **Looks:** `HumanCustomizationComponent_C` (178457) has 16 OnRep_ functions, one per part. The server replicates a data-table row name per part; each PC's OnRep loads that mesh/colour. This matches our probe C (set RowName, call OnRep).
- Movement: native `AbioticCharacterMovementComponent` (39778); sprint/aim/crouch functions take `bClientSimulation`, the stock pattern for running the same code on simulated proxies.
- The dump does not list replication flags, so which exact variables replicate is inferred from the OnRep names.

## 5. What this means for our crew bodies
- Our probes A, B, C ran in a single-player client, where that client is also the server. They prove spawn, AI controller, pathing and looks **on the host only**.
- For other players to see a crew member: spawn it on the server (host or dedicated). A player-character actor replicates by default [engine], so position and walk animation should follow with no extra work [unverified].
- Looks: setting RowName on the server should replicate and fire OnRep on clients by itself; our manual OnRep call is then only needed on the server/host side [unverified].
- Risks [unverified]: (a) the body's setup may expect a PlayerState/owning player (overhead name, voice, Client_SetupCharacter never runs); (b) the game may count it as a player (sleep vote, enemy targeting, save data); (c) first-person-only parts may show on an unowned body; (d) walk animation itself, we have stills only.
- A mod running only on a joining client cannot make crew that others see. FairCrew must run on the host/server.

## 6. Tests to run (dedicated-server harness)
1. Server spawns a body, a second client joins: is it visible, at the same spot?
2. Server walks it: does the client see legs moving (short video, not stills)?
3. Server sets random look: does the client see the same clothes without calling OnRep there?
4. Client joins after spawn + look: still correct (late join)?
5. Does the server treat it as a player: sleep, enemy aggro, player count, save file?
6. Damage/down a body: no crash from Client_ calls with no owner?
