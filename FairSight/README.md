# FairSight (Abiotic Factor, UE4SS Lua)
NPCs stop tracking your live position through walls after losing sight. Stock `LastSawTargetCheatDuration`: zombies/coworkers/Boxy 999999 s, BogMan/bosses/Snowman/Tarasque 120 s, Robot_Defense 60 s. FairSight caps every AI controller at 2 s (stock parent default); sight/hearing untouched.
Install: UE4SS in Win64, copy `FairSight` to `ue4ss\Mods`, add `FairSight : 1` to mods.txt. Log: `C:/re/abioticfactor/fairsight_log.txt`. Edit `CAP` in main.lua.
Test mode: a file `C:/re/abioticfactor/fairsight_test.txt` holding a map name opens it from the menu and spawns a zombie (dev only).
