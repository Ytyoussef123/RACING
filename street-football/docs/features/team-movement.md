# Team movement

Last change: 2026-11-15, after a pass the passer stops, then jogs (`AfterPass`; branch `feature/after-pass`, commit `3fc24de`). Before that: markers keep room (4.5 m) around a pressed ball; final version of the team movement work (branch `feature/team-movement`, commit `cf0ecf7`)

## What it does now
- Goal: players create empty space and are not all near each other (user request, 2026-11-15). Spacing about 5 m. Calling runs (asking a teammate to run) is NOT done, planned for later.
- "In possession" (`AttackRoles.in_possession`): our holder has the ball, or our pass is on its way to a teammate.
- With the ball, at every decision tick the team brain gives each outfield player without the ball a job (`AttackRoles.assign`): SUPPORT, FORWARD or COVER.
  - The players nearest the job spots take them (cheapest total distance over all permutations). A player keeps his job unless another is clearly closer (`role_keep_bonus` 3 m). The formation role prefers its job (`role_jobs`: DEF -> cover, MID -> support, WING -> forward, ATT -> forward; `role_job_bonus` 2 m), so formations still matter.
  - When our keeper has the ball nobody has a job: they take their formation slots to offer an outlet (as before).
  - Winning the ball gives the jobs at once, not at the next decision tick.
- Spots (`AttackShape`):
  - SUPPORT: `support_distance` 6.5 m from where the carrier will be in `support_lead_seconds` 0.4 s, at 45, 90 or 135 degrees either side (`support_angles`). The angle is chosen at each decision (`best_support_angle`): clear lane from the carrier (+2), room from opponents (0.4 per m up to 5 m), some progress (0.8 x cos), away from the walls (1 per m, clamped), at least 6 m from the forward's and cover's spots (0.5 per missing m), bonus 0.6 for keeping the current angle.
  - FORWARD: level with the opponent's last outfield defender minus 1 m (pins him back), at least 3 m ahead of the ball, wide (0.6 of the half width) on the side away from the ball. He switches side only when the ball is 2.5 m or more off the middle.
  - COVER: 10 m behind the ball near the middle. When the ball is too deep for that (`cover_min_frac` 0.15) he comes level with it and moves across (`cover_wide_z` 0.45 of the half width), so the carrier has a square pass instead of a teammate at his heels.
- Every attacking spot steps 1.5 m away from an opponent within 2.5 m of it (`get_open`, uses the nearest opponent; before it used the first one found) and is pushed away from teammates closer than 5 m (`spacing_min` 5, `spacing_push` 0.7). A player whose way to his spot passes within 3 m of the carrier goes around him (`detour_radius` 3, `detour_margin` 1.2). A player more than 4.5 m from his spot sprints (`job_sprint_distance`).
- Runs in behind: the forward starts a run when the carrier faces forward (facing 0.2+), there are 5 m or more behind the last defender, he is not already past him, and the run's spot stays within 20 m of the carrier. Chance per second `run_rate` by difficulty (easy 0.25, normal 0.5, hard 0.8). He sprints to 3 m behind the last defender (not past 0.88 of the court), in a lane bent 40 % toward the middle, for 2.4 s at most or until he gets there, then 2.5 s before the next run. Losing the ball ends the run.
- Through pass: the carrier AI plays a through pass to a teammate on a run or give-and-go who is moving 3 m/s or more, further up, 3 to 20 m away, with a clear lane to 3 m in front of him (`through_tendency` by difficulty: easy 0.3, normal 0.55, hard 0.75). The human uses the THROUGH button for the same runs.
- Give-and-go: after a pass by one of ours (not the keeper, never the last man back), the passer runs 7 m up the court, a little toward the middle and 2 m to the side away from the receiver, sprinting, for 1.6 s (`give_go_chance` by difficulty: easy 0.3, normal 0.6, hard 0.85).
- Without the ball:
  - The nearest outfield player presses (chaser, as before).
  - While the other side has the ball (or its pass is on the way) and the ball is 12 m or more from our goal, the outfield player nearest the cover point covers: 6 m behind the ball on the line to our goal (at most half way). `SupportAI.cover_point`.
  - A loose ball gets one player only, as before.
  - Marking: of the free opponents in our part of the court (`mark_zone_frac` 0.62), the most advanced ones, as many as we have markers, are matched closest pair first (no crossing).
  - Defending spots (cover, mark, zone) keep 3 m from teammates (`defend_spacing_min` 3, push 1.0). While a teammate is nearer the ball, a marker or zone player stays 4.5 m from it (`press_room`): at most the presser is around the ball.
- After a pass (`AfterPass`, details in `ai.md`): the passer stands still 0.25 s, then jogs 1.2 s (no sprint, 0.7 of run speed) before he follows his job. A give-and-go or a run in behind starts right after the short stop, so they still happen.
- Carrier pass weights moved from code to `ai.json` (`pass_progress_weight` 3, `pass_open_weight` 0.3, `pass_open_cap` 5, `pass_blocked_score` 5), same values.
- Measured (MATCH SPACING, 6 fixed-seed AI matches, old AI -> new): nearest teammate 5.3 m -> 5.3 m; two teammates closer than 3 m 39 % -> 34 % of the time; 3+ of a side within 4 m of the ball 7 % -> 8 %. With the ball 5.5 m -> 5.8 m, 40 % -> 33 %, 6 % -> 7 %. Settled possession (with the ball 2 s+) 5.6 m -> 6.2 m, 43 % -> 37 %, 5 % -> 6 %. Without the ball 5.0 m -> 4.9 m, 42 % -> 36 %, 10 % -> 11 %. Loose ball 5.6 m -> 5.3 m, 32 % -> 31 %, 2 % -> 3 %. Passes per team per match 38 -> 52 (completion 74 %).
- Most remaining close pairs with the ball are carrier + support right after short passes; without the ball, the presser and a marker.

## Where it lives
- Code (new): `scripts/ai/attack_roles.gd` (AttackRoles): `in_possession`, `carrier_of`, `tick` (run and give-and-go timers), `assign`, `clear`, `end_run`.
- Code (new): `scripts/ai/attack_shape.gd` (AttackShape): `intent_for`, `support_spot`, `best_support_angle`, `forward_spot`, `cover_spot`, `run_spot`, `run_lane`, `may_run`, `give_go_spot`, `last_defender_frac`, `get_open`, `spaced`, `around_carrier`, `clamp_to_court`.
- Code (changed): `scripts/ai/support_ai.gd` (`cover_point`, `_apart`, `_keep_room`; the attacking path goes to AttackShape), `scripts/ai/team_brain.gd` (`cover`, `support_angle`, `forward_side`, `kick_seen`, `_pick_cover`, marking), `scripts/ai/carrier_ai.gd` (`_runner`, through pass), `scripts/ai/ai_player_state.gd` (`AttackRole` enum, `attack_role`, `run_left`, `run_cooldown`, `run_z`, `go_left`, `go_target`), `scripts/ai/ai_tuning.gd` (`run_rate`, `through_tendency`, `give_go_chance`).
- Numbers: `data/config/ai.json`: all keys named above; the per-difficulty ones (`run_rate`, `through_tendency`, `give_go_chance`) in `difficulties.*`.
- Tests: `tests/team_ai_test.gd` + `.tscn`: 31 checks (possession, jobs, support, forward, cover, spacing, get open, detour, runs, through pass, give-and-go, keeper's ball, defense, brains); prints `TEAM AI TESTS DONE: N failure(s)`. `tests/match_sim_test.gd`: `MATCH SPACING` lines. `tests/screenshot_tour.gd`: top views `match_top_1..4`.

## History (newest first)
- 2026-11-15: after a pass the passer stops 0.25 s and jogs 1.2 s (`AfterPass`); give-and-go and runs in behind start right after the short stop. Why: user request, a natural movement after a pass. Match spacing after the change (6 AI matches): nearest teammate 5.4 -> 5.3 m, two closer than 3 m 31 -> 34 %, 3+ near the ball 8 %. Branch `feature/after-pass`, commit `3fc24de`.
- 2026-11-15: slower players: the AI's through ball needs a runner at 2.1 m/s or more (`through_min_runner_speed` 3.0 -> 2.1, see `ai.md`). Match spacing after the change: 5.4 m to the nearest teammate (same), two teammates closer than 3 m 31 % -> 30 %, 3+ near the ball 8 % (same). Branch `feature/player-speed`, commit `bea4541`.
- 2026-11-15: markers and zone players keep 4.5 m from a ball being pressed (`press_room`). Why: with a teammate already at the ball, markers still crowded it. Branch `feature/team-movement`, commit `cf0ecf7`.
- 2026-11-15: off-ball players go around the carrier; jobs are given at once when the ball is won; defending spots keep the full 3 m. Why: after a pass, players ran to their new spot straight past the new carrier (carrier + support was the main close pair with the ball), and a won ball waited up to one decision tick for the jobs while the players were still bunched from defending. Branch `feature/team-movement`, commit `c4df0bd`.
- 2026-11-15: defenders keep 3 m apart; markers matched closest pair first. Why: presser + marker was the main close pair without the ball (31 % of that time), and markers crossed the court to reach their man. Branch `feature/team-movement`, commit `98e43a5`.
- 2026-11-15: support leads the carrier (0.4 s, 6.5 m), far jobs sprint (4.5 m), give-and-go side step, cover 6 m back only with the ball 12 m or more from our goal. Why: the support fell behind a running carrier and was caught by him, the shape formed slowly after a change of possession, a give-and-go ran into the receiver, and the cover crowded the ball near our goal. Branch `feature/team-movement`, commit `513bed3`.
- 2026-11-15: cover picked as the player nearest the cover point, none on loose balls; the match test prints the most frequent causes of close pairs. Why: both teams sent a cover to loose balls and the cover stayed near the ball. Branch `feature/team-movement`, commit `b694825`.
- 2026-11-15: spacing measured by phase; cover beside a deep carrier; defensive cover 5 m. Why: the first version made bunching worse. Branch `feature/team-movement`, commit `2ff5335`.
- 2026-11-15: first version: jobs off the ball, runs in behind, through passes, give-and-go, cover, danger-first marking, team AI tests, top view pictures. Why: user request, players should create empty space. It made bunching worse (close pairs 51 %, 3+ near the ball 19 %): the cover was the second nearest player to the ball and stayed near it, both teams sent a cover to loose balls, the cover stood at the carrier's heels when the ball was deep, markers crossed the court. Branch `feature/team-movement`, commit `c5888cf`.
- 2026-11-15: spacing measure counts teammates closer than 3 m (baseline 39 %), commit `e67afba`; MATCH SPACING measure (baseline 5.3 m, 7 % with 3+ near the ball), commit `d3976eb`. Why: measure first, then change. Branch `feature/team-movement`.
- 2026-11-15: the old AI (`e67afba`) was measured with the same measure on a throwaway branch `feature/team-movement-baseline` (commits `5a25225`, `d577869`; not to be merged) to compare against.

## Do not undo
- The cover is the player nearest the cover point (not the 2nd nearest to the ball), and only when the other side has the ball. A loose ball gets one player.
- Defenders keep 3 m apart and 4.5 m from a pressed ball.
- Off-ball players go around the carrier.
- Jobs are given at once when the ball is won.
- Formations still matter (`role_jobs`, `role_job_bonus`); with the keeper's ball nobody has a job.
- Spacing is measured by phase with MATCH SPACING and compared with the old AI. Do not judge by the overall average only.
- Balance after this work: 3.67 goals, 31.5 shots, 16.0 saves per 150 s match (was 4.17 / 27.8 / 15.3).
- Calling runs is planned, not done.

## How to check after a change
- CI: step "Team AI tests (headless)" prints `TEAM AI TESTS DONE: 0 failure(s)`.
- CI: `MATCH SPACING` lines (per phase, and causes); compare with the numbers above. `MATCH BALANCE` too.
- Top views `match_top_1..4` in the screenshot tour: players spread, not in a clump.
- Phone test: NOT done yet (waits, like the earlier branches; nothing merged to main). Watch the support, a run in behind, a give-and-go, the cover.
