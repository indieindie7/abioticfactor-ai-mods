# Multi-agent testing for games and robots (2026-11-13, v2: source pages opened)

Question: how do people do multi-agent testing for games or robots?
Method: 6 web searches, then every cited source opened as text (arXiv abstracts, GDC Vault overviews, EA, gamedeveloper.com, 80.lv, NVIDIA docs, PyPI, ROS index, White Rose, Crossref).
Checked: every claim below was read on the page named, unless marked "unverified". Full talks and full papers were not read (overviews and abstracts only).
Corrected from v1: two sources were matched to the wrong work (the GDC link given for The Division is the Battlefield V talk; arXiv 2509.16478 is not the path-finding paper); claims that were not on the pages are removed or marked.

## Short answer
1. Scripted bots are the base layer: they drive the real client, run on every change, and scale from one scripted case to a full server of bots.
2. Learned or curious agents go on top to reach states scripts never try; they give coverage, not pass/fail.
3. The hard part is the oracle (knowing a run was wrong). Answers in use: bots that report their own failures, invariants, metamorphic relations, robustness scores, baselines compared between runs.

## 1. Games: what studios do
- EA DICE, Battlefield V (GDC, Jonas Gillberg): "AutoPlayers", autonomous bots used from full 64-player soak tests down to specific scripted test cases; end users control them, which led to unexpected uses. [1]
- Ubisoft Reflections, The Division (GDC, Paredes and Jones): "Client Bots" take control of the player, mimic human input and report issues (missions that cannot be completed, performance statistics). Uses: automated mission playthrough with reports, follow bots so one QC person or designer can test multiplayer missions alone, street wandering for performance data, bug reproduction. [2][3]
- Rare, Sea of Thieves (GDC, Robert Masella): built with automated gameplay tests from the start; a framework so team members write tests quickly, several test types, a chosen level of coverage. Tests run on built executables and on the build farm through TeamCity; a developer shows passing tests in code review before commit, then the build server runs all tests. [4][5] The "10,000 tests" figure and "bots explore interactions": unverified (not on the pages opened). A follow-up talk adapted the method to Minecraft (title only). [6]
- EA SEED (CoG 2023, Gillberg, Bergdahl, Sestini et al.): an experimental RL system added to the existing scripted-bot test solution to raise coverage, in AAA games including Battlefield 2042 and Dead Space (2023); the paper lists the biggest time sinks. [7][8]

## 2. Games: research
- Curiosity agents (Gordillo et al. 2021): agents rewarded for novelty, trained to maximise game-state coverage in a complex 3D scenario. [9]
- CCPT (Sestini et al. 2022): curiosity plus imitation, agents explore near expert demonstration paths; higher coverage and bug discovery than baselines. [10]
- cMarlTest (Ferdous et al. 2025): several curious agents working together on a 3D game; higher coverage on three coverage criteria and less time than the single-agent version. [11]
- Industry gap (Politowski et al.): developers rely almost only on manual playtesting; a literature review plus developer survey studies the gap between academic tools and what studios need. [12][13] (v1's list of method classes: not on these pages, removed.)
- LLM testers: TITAN (2025), an LLM agent for MMORPG testing with state abstraction, action prioritising, memory with self-correction and LLM oracles; 95 % task completion on two commercial MMORPGs, four previously unknown bugs, deployed in eight QA pipelines. [14] GBQA (2026): 30 games, 124 human-verified bugs, built by a multi-agent system that makes games and injects bugs; the best model found only 48.39 % of the bugs. [15]

## 3. Robots
- CI: RoboCI v0.0.3 (public alpha, "not production safety validation"): closed-loop simulation runs, failure replay, named baselines, regression compare, reports; CARLA/Isaac/Gazebo/ROS2 adapters need a local runtime. [16]
- Scenario suites: NVIDIA Halos Outside-In Safety blueprint: five scenarios on one stock warehouse scene that differ only in the three character behaviour trees; everything else stays identical. [17] Frontiers 2024: developer interviews say managing scenario variation is a major barrier to simulation testing. [18]
- Fleet scale: PyBulletFleet, a kinematics-first simulator for large multi-robot fleets (100-robot demos), built for faster-than-real-time evaluation. [19]
- Swarm faults by search: genetic algorithms evolve test environments that expose faults in a flocking algorithm. [20] RSFuzz: a robustness score over behavioural constraints guides scenario generation, attacks key swarm nodes with one or several attackers; 17.75 % more effective and 38.4 % more efficient than prior work on three swarm algorithms. [21]
- Oracles: CoCoMagic combines metamorphic and differential testing with co-evolutionary search to find behaviour differences between versions of an autonomous system. [22] Run-time search for multi-agent systems is proposed as a position paper only. [23] (v1's "10 metamorphic relations for path finding": source not found, removed.)

## 4. What applies to our crew harness (my reading, not from a source)
- We already do pattern 1 (crew_harness.py H1-H13, agent vs agent in one client). The Division's "follow bots so one person tests multiplayer alone" is close to our bot owner + crew.
- Cheap next steps: (a) bots report their own failures as they happen (stuck, gave up, under the floor) instead of only end-of-row checks; (b) metamorphic rows (mirrored start must end mirrored; a second crew member must not change the owner's path); (c) named baseline per run (tries, time per row) and compare, as RoboCI does; (d) a soak run: several crew wandering for an hour, log every "gave up".
- Not now: training RL agents (the EA paper is mostly about how costly deployment was).

## Sources (all opened unless noted)
1. https://gdcvault.com/play/1025905/AI-for-Testing-The-Development
2. https://gdcvault.com/play/1026069
3. https://80.lv/articles/gdc-using-ai-controlled-players-to-test-the-division/
4. https://gdcvault.com/play/1026366/Automated-Testing-of-Gameplay-Features
5. https://www.gamedeveloper.com/design/how-rare-automates-testing-for-ai-and-more-in-sea-of-thieves-part-4-of-4-
6. https://gdcvault.com/play/1027345/Lessons-Learned-in-Adapting-the
7. https://arxiv.org/abs/2307.11105
8. https://www.ea.com/seed/news/cog23-challenges-deploying-rl-agents-game-testing
9. https://arxiv.org/abs/2103.13798
10. https://arxiv.org/abs/2202.10057
11. https://arxiv.org/abs/2502.14606
12. https://arxiv.org/abs/2103.06431
13. https://arxiv.org/abs/2202.12777
14. https://arxiv.org/abs/2509.22170
15. https://arxiv.org/abs/2604.02648
16. https://pypi.org/project/roboci/
17. https://docs.nvidia.com/halos/outside-in-safety/testing/srr/scenarios
18. https://doi.org/10.3389/frobt.2024.1363281 (read through the Crossref record)
19. https://index.ros.org/r/pybulletfleet/
20. https://eprints.whiterose.ac.uk/id/eprint/117325/
21. https://arxiv.org/abs/2409.04736
22. https://arxiv.org/abs/2509.16478
23. https://arxiv.org/abs/2205.05502
