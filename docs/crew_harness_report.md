# FairCrew crew harness 2026-11-13 19:14

| row | check | result | evidence |
|---|---|---|---|
| H1 | bot owner + crew spawn with AI controller | PASS | spawn Crew2 at -17262 13605 208 ctrl=Abiotic_AI_Controller_ParentBP_C |
| H2 | random look, 9 parts, two bodies differ | PASS | Head=Head_F01a HairStyle=Hair_Hudson HairColor=HairColor_Silver HeadAccessory=Gl |
| H3 | bodies=3 real players=1 | PASS | who bodies=3 real=1 crew=1 |
| H4 | recruited with a gift | PASS | recruited Crew2 with Bandage took=true friend=60 rest=50 fed=90 |
| H5 | crew follows the owner (apart < 600 uu after the walk) | PASS | arrived=True apart=245 |
| H6 | walking: velocity > 50, anim Speed > 50, moving in >= 2 samples | PASS | max vel=500 max animSpeed=500, moving in 4/12 samples |
| H7 | moved in to the owner's bed | PASS | moved in Crew2 bed=2028a6e00 |
| H8 | tired crew stays home, rest recovers | PASS | crew 1 Crew2[home f=64 r=5 -> crew 1 Crew2[home f=64 r=11 |
| H10 | test body: hurdle by jump, bar by crouch (ends > 620 uu down the lane, bar ends at 600) | PASS | start=(-17409, 13563, 216) end=(-17409, 14207, 216) blocked tries=6 |
| H11 | test body: walks to the ladder and climbs to the platform (Z > 380) | PASS | end=(-17126, 14463, 416) climb top at -17330,14463,460 |
| H12 | crew member: hurdle by jump, bar by crouch (ends > 620 uu down the lane, bar ends at 600) | PASS | start=(-17409, 13563, 180) end=(-17409, 14188, 180) blocked tries=9 |
| H13 | crew member: walks to the ladder and climbs to the platform (Z > 380) | PASS | end=(-17191, 14463, 416) climb top at -17331,14463,456 |
| H9 | client alive, no Lua errors | PASS | alive=True errors=0 |
