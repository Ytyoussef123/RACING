# Match flow

Last change: 2026-11-15, goal kicks start in the keeper's hands, the human controls his keeper when he has the ball (branch `feature/keeper-ball`, commit `346d461`). Before that: 2026-11-15, human assists moved out of `match.gd` into `HumanAssists` (branch `feature/speed-modes`, commit `a89cab9`)

## What it does now
- 5v5: each team has a keeper and 4 outfield players. The human's team attacks to the right (orange, keeper yellow). Goalkeepers protect the goal automatically (AI); the human controls his keeper only when the keeper has the ball (below).
- Keeper with the ball: `HumanControl` gives the human his keeper whenever the keeper has the ball (and when a back-pass is coming to him); on defense the keeper stays automatic. In his hands he cannot leave his area; at his feet he plays like a normal player. Details: `ai.md` (rules), `passing-and-receiving.md` (throw, long kick, back-pass), `touch-controls-and-hud.md` (buttons).
- Area size (unchanged): `goal_area_depth` 3.5 m and `goal_area_width` 8.0 m on `cage_concrete` and `open_lot`; 3.2 m and 7.5 m on `rooftop_cage` and `beach_sand` (`data/courts/*.json`).
- Formations: 2-1-1, 1-2-1, 1-1-2, 2-2, 1-1-1-1 (`data/formations/*.json`: slot role, x 0..1 from own goal, z -1..1). Default 2-1-1; the opponent plays 1-2-1. The human can change formation during the match from the PAUSE menu (FORMATION).
- Slots are assigned by `SlotAssigner` for the best total overall, with the keeper always in goal, at kick-off and on every formation change.
- Clock: 180 s by default (3, 4 or 5 minutes chosen in the menu). Score and clock at the top, crew short names next to the score.
- Goal: GOAL! message for 2 s, then kick-off by the team that conceded. Restarts after the ball goes out (open courts): KICK-IN, CORNER or GOAL KICK for the team that did not touch it last, message 1.5 s. A goal kick starts with the ball in the keeper's hands (`RestartPlacer.apply_restart`). Courts with walls have no restarts.
- Full time: FULL TIME message (4 s), then the results screen (YOU WIN / DRAW / YOU LOSE, score, goal scorers and times, match stats, coins, REMATCH, MAIN MENU).
- Coins after every match: win 150, draw 80, loss 50, plus 15 per goal scored, times 0.8 Easy, 1.0 Normal, 1.4 Hard (`data/config/progression.json`).
- Kit clash: when the two kits are too close, the away crew wears its alternate kit.
- Rules: one player controls the ball at a time (shared `Possession`); a tackle in reach can knock the ball loose; a keeper with the ball in his hands cannot be tackled; players push each other apart.
- Auto-switching of the controlled player (when a pass leaves, when a teammate gets the ball, when defending and a teammate is clearly closer).
- Match events channel: `MatchContext.emit_event(kind, at, strength, label)` feeds sounds and effects (kicks, tackles, saves, skills, ball hits on ground, wall, post, net). Gameplay code does not call sound or effects directly.
- Match statistics (`MatchStats`): shots, saves, passes and passes completed, balls won, possession time. Goal scorers and times are recorded.
- Courts: `cage_concrete`, `open_lot`, `rooftop_cage`, `beach_sand` (two are unlocked with coins).

## Where it lives
- Code: `scripts/gameplay/match.gd` (match scene script: builds the match, runs frames, goal and out detection). `scripts/gameplay/match_flow.gd` (MatchFlow): `start()`, `tick_clock()`, `stop()`, `tick_stop()`, `finish()`, `clock_text()`. `scripts/gameplay/restart_placer.gd` (RestartPlacer): `kickoff()`, `plan_out()`, `apply_restart()`. `scripts/gameplay/match_context.gd` (MatchContext): `emit_event()`, `add_team()`. `scripts/gameplay/team.gd` (Team): own and target goal, `set_formation()`, `assign_slots()`. `scripts/gameplay/team_factory.gd` (TeamFactory): `build()`, `kits_clash()`. `scripts/gameplay/slot_assigner.gd` (SlotAssigner). `scripts/gameplay/match_stats.gd` (MatchStats). `scripts/data/formation_data.gd` (FormationData). Scenes: `scenes/match/`.
- Numbers: `data/config/match.json` -> `match_seconds` 180, `goal_message_seconds` 2.0, `full_time_message_seconds` 4.0, `restart_message_seconds` 1.5, `default_formation`, `default_difficulty`, `formations`, `difficulties`, `courts`, `default_home_team` "my_crew", `default_away_team` "rooftop_rebels", `auto_switch`, `auto_switch_margin` 2.5, `switch_cooldown` 0.8, `restart_clear_distance` 3.0, `restart_inset` 0.4, `kickoff_taker_offset` 0.6, `kit_clash_distance` 0.35.
- Numbers: `data/config/progression.json` (coins). `data/formations/*.json` (5 formations). `data/courts/*.json`.
- Tests: `tests/match_sim_test.gd` (6 full AI matches, goals counted, ball never stuck, everyone in the court); `tests/stats_test.gd` (slot assignment); `tests/progression_test.gd` (rewards, e.g. a 3-1 win on Normal = 195 coins); `tests/ui_flow_test.gd` (menu choices, results screen).

## History (newest first)
- 2026-11-15: goal kicks start with the ball in the keeper's hands (`RestartPlacer.apply_restart`); `HumanControl` controls the human's keeper whenever he has the ball (and when a back-pass is coming to him), on defense the keeper stays automatic. The ball bouncing off bodies moved from `BallHandling` to `scripts/gameplay/body_bounce.gd` (`BodyBounce.apply`); `Player.reset_to` also clears `ghost_timer`. Why: user request (keeper with the ball); file size rule. Branch `feature/keeper-ball`, commit `346d461`.
- 2026-11-15: the human assists moved from `match.gd` to `HumanAssists` (`scripts/gameplay/human_assists.gd`) to keep `match.gd` under about 300 lines. No change to the rules. Branch `feature/speed-modes`, commit `a89cab9`.
- 2026-11-14: Phase 7: My Crew is the default home side, coins after every match shown on the results screen, match record saved, 4 courts. Branch `feature/progression`, commit `f78448c`.
- 2026-11-14: Phase 6: match events feed sounds and effects (kicks, tackles, saves, skills, ball hits), goal celebration, camera shake on goals. Branch `feature/polish`, commits `cff05f4`, `16fa679`.
- 2026-11-14: Phase 5: menus; quick match flow (crews, formation, court and rules, match length 3/4/5 min); results screen with scorers and stats; PAUSE menu (RESUME, FORMATION, QUIT MATCH). Branch `feature/menus`, commit `88497f3`.
- 2026-11-14: Phase 4: match statistics (`f613738`), 3 AI matches with fixed seeds and a balance report (`255662b`), crew short names on the HUD and alternate kit on a clash (`d4786b9`). Branch `feature/player-stats`.
- 2026-11-14: touch dribbling and shoulder charge (user feedback). Branch `feature/five-v-five`, commit `1d96a5e`. Bigger court 36 x 22 m, receive assist, button layout (`6055f1d`). PRESS button and pass assist (`6874e1f`). All same branch.
- 2026-11-14: Phase 3: 5v5, formations, score, clock, kick-off, restarts, FULL TIME. Branch `feature/five-v-five`, commit `02cd4ce`.
- 2026-11-14: Phase 2: one player, court 30 x 18 m, GOAL! then kick-off after 2 s, OUT after 1.5 s. Branch `main` (`feature/core-match`), commit `19add2a`. Phase 1 setup `3193378` (`main`).

## Do not undo
- 5v5 rules and the 5 formations (2-1-1, 1-2-1, 1-1-2, 2-2, 1-1-1-1). Slots are assigned for the best total overall with the keeper always in goal.
- Kit clash gives alternate kits to the away crew. This was needed so teams stay readable.
- Match events go through `ctx.emit_event`: one place feeds sounds and effects, so gameplay code does not call them directly.
- Every player is driven by `PlayerIntent`; one shared `Possession` so only one player controls the ball at a time.
- Results and coins at the end of every match; the AI match test uses two fixed crews (never My Crew) so balance numbers stay comparable.
- A full AI match runs in CI: it catches stuck balls and broken rules before the phone test.
- Tackling when nobody has the ball does not stun.
- Keepers protect the goal automatically; the human controls his keeper only with the ball (user decision, 2026-11-15). Goal kicks start in the keeper's hands.

## How to check after a change
- CI: all suites pass, no script errors. `tests/match_sim_test.tscn`: `MATCH BALANCE` line and the match results.
- Screenshot tour (`tests/screenshot_tour.gd`, decode with `.github/scripts/decode_screenshots.py`): match, pause menu, results screen.
- Phone test: play to FULL TIME on each court, score and concede (kick-off by the team that conceded), send the ball out on Open Lot, change formation, check coins on the results screen.
