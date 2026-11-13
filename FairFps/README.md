# FairFps v0.2 (Abiotic Factor, UE4SS Lua)
FPS readout and a scrolling frame-time bar graph drawn on the HUD (120 bars; lines at 60 and 30 fps), on at start, F8 toggles. Frame-time log every 10 s in `C:/re/abioticfactor/fairfps_log.txt`.
Status: tested on the real client 2026-11-10 (graph and text, F8 toggle, log: PASS; rows in ../TESTPLAN.md). The graph draws on the HUD canvas, so full-screen menus cover it.
v0.1 used the engine's `stat unitgraph`, which draws nothing in the shipping build.
