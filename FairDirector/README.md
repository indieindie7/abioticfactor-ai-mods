# FairDirector v0.2 (Abiotic Factor, UE4SS Lua) — UNVERIFIED in a world
Director-side pacing: stress per player = 0.5 low head+torso HP + 0.3 recent damage + 0.2 NPCs within 15 m.
Stress >= 0.65 -> relax 60 s (NPCCap x0.5, spawner SpawnCooldown_Default x2). Calm <= 0.25 for 120 s -> build (cooldown x0.75).
Never touches NPC senses (FairSight does that). Log: C:/re/abioticfactor/fairdirector_log.txt.
