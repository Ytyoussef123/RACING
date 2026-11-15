# Shooting

Last change: 2026-11-15, every shot is aimed on target, tight-angle and back-to-goal error, kicker lets the ball through (branch `feature/shot-on-target`, commits `436f156`, `acc04df`). Before that: 2026-11-15, accuracy depends on the speed mode (branch `feature/speed-modes`, commit `a89cab9`).

## What it does now
- Aim (`scripts/gameplay/shot_aim.gd`, `ShotAim.target`): every shot is aimed at a point on the opponent's goal line. A stick pointing at or near the goal keeps its aim (it can still miss up to `shot_assist_margin` 1.5 m past a post); a stick pointing elsewhere aims `shot_post_inset` 0.45 m inside the post on that side; no stick aims at the corner away from the keeper. The point is computed when SHOOT is released (a queued shot keeps that point); the shot direction goes from the ball to it.
- The error still decides if it is on target: finishing, long-shot distance, weak foot, speed mode, first-time skill, plus a tight angle (goal seen under `shot_tight_angle_degrees` 20 degrees: error up to x`shot_tight_error_mult` 1.6) and the back to the goal (shot more than 90 degrees from the facing: up to x`shot_turn_error_mult` 1.5).
- After any kick the kicker's body lets the ball through for `kick_pass_through_seconds` 0.15 s (`player.ghost_timer`).
- In our own half SHOOT becomes CLEAR (see `touch-controls-and-hud.md`).
- The AI's aim already crosses the goal, so its shots are aimed as before.
- Planned, not done: a "Blitz" shot (a curling power shot from the reference game), asked by the user for later.
- SHOOT: hold to charge (`shot_charge_time` 0.9 s, power bar above the player), release to shoot. Speed between `shot_speed_min` 12 and `shot_speed_max` 26 m/s, lift between 0.5 and 5.5. Turning while shooting curls the ball (`shot_curve_from_turn`).
- Stats: shot power scales the speed (`shot_speed_mult`); finishing sets the aim error (`shot_error_degrees`); long shots add error per meter beyond `long_shot_distance` 12 m (`long_shot_error_per_meter`).
- Speed mode: the aim error is multiplied by x0.85 walking, x1.15 sprinting, x1.2 in a knock-on, for everyone, AI too (`player.json` -> `pace_error_mult_walk`, `pace_error_mult_sprint`, `pace_error_mult_knock_on`; `BallHandling._pace_mult`).
- Weak foot: a kick aimed well to the weak side (more than `weak_side_degrees` 35 off the facing) has more error, by weak-foot stars (`weak_foot_error_mult` [2.6, 2.0, 1.5, 1.15] for 1 to 4 stars).
- Special skills: `first_time_shot` makes a one-touch shot (the shooter does not hold the ball) more accurate (error x0.6, `skills.json` -> `first_time_shot_error_mult`); `rabona` removes the weak-foot penalty.
- A shot needs the ball within `kick_reach`; a shot asked early is queued (kick buffer) and played when the ball is reached; the aim is chosen at the press.
- On defense the SHOOT button becomes TACKLE; the earlier version (PRESS on this button) was replaced (see `defending.md`).
- The AI shoots in range (aims at the corner away from the keeper with a difficulty-based error). Match stats count shots.

## Where it lives
- Code: `scripts/gameplay/shot_aim.gd` (ShotAim): `target`. `scripts/gameplay/kick_accuracy.gd` (KickAccuracy): `with_error`, `weak_foot_mult`, `pace_mult` (moved out of `BallHandling`), `shot_angle_mult`.
- Code: `scripts/gameplay/ball_handling.gd` (BallHandling): `_shoot`, `_kick`, `_aim_direction`, `_queue`, `_play_queued`. The charge and release come from `PlayerIntent` (`scripts/gameplay/player_intent.gd`) filled by `HumanInput`/touch controls.
- Code: `scripts/physics/ball_physics.gd` (BallPhysics): `kick(velocity, spin)`, curve.
- Numbers: `data/config/player.json` -> `shot_charge_time`, `shot_speed_min`, `shot_speed_max`, `shot_lift_min`, `shot_lift_max`, `shot_curve_from_turn`, `kick_reach`, `kick_max_ball_height`, `kick_cooldown`, `kick_buffer_seconds`, `shot_post_inset`, `shot_assist_margin`, `shot_tight_angle_degrees`, `shot_tight_error_mult`, `shot_turn_error_mult`, `kick_pass_through_seconds`.
- Numbers: `data/config/stat_effects.json` -> `shot_speed_mult`, `shot_error_degrees`, `long_shot_error_per_meter`, `long_shot_distance`, `weak_side_degrees`, `weak_foot_error_mult`. `data/config/skills.json` -> `first_time_shot_error_mult`. `data/config/controls.json` -> `shoot_position`, `shoot_radius`.
- Numbers (AI): `data/config/ai.json` (shot range, aim and error per difficulty).
- Tests: `tests/physics_smoke_test.gd`: "dribble and shot score at +x", "shot over the bar is no goal". "shot aim: stick along the goal line still aims inside the goal", "shot aim: aiming at the goal keeps the aim", "shot aim: aiming wide of the goal goes inside the post on that side", "shot aim: no stick aims at the corner away from the keeper", "shot on target: running along the goal line, the shot heads on goal". `tests/stats_test.tscn`: finishing, shot power, long shots, weak foot. `tests/match_sim_test.gd` (shots in `MATCH BALANCE`).

## History (newest first)
- 2026-11-15: every shot is aimed at the opponent's goal (`ShotAim.target`; the stick picks the side), new error for tight angles and the back to the goal, `KickAccuracy` split out of `BallHandling`, and the kicked ball passes through the kicker for 0.15 s (a shot or pass back across his body had hit his own collision circle). Why: the user asked that a shooter not lined up with the goal still shoots on target. Balance after: 4.67 goals, 30.3 shots, 16.2 saves (keeper save chance +0.05, see `ai.md`). The "Blitz" shot is planned, not done. Branch `feature/shot-on-target`, commits `436f156`, `acc04df`, `2bcb10d`.
- 2026-11-15: aim error by speed mode (x0.85 walking, x1.15 sprinting, x1.2 knock-on). Why: the user's design (a little better walking, worse sprinting). Branch `feature/speed-modes`, commit `a89cab9`.
- 2026-11-14: shots wait for the ball (kick buffer) and the player is run onto the ball. Branch `feature/five-v-five`, commits `6055f1d`, `1d96a5e`.
- 2026-11-14: Phase 4: finishing, shot power, long shots and weak foot drive power and accuracy; match stats count shots. Balance: with stats, most AI shots missed (1.67 goals per 150 s), so AI aims 55 cm inside the post (was 35), smaller AI aim errors, AI skips shots at an angle under 9 degrees unless within 6 m, keeper save chances lowered; result 3.67 goals per 150 s. Branch `feature/player-stats`, commits `d4786b9`, `f613738`, `9641a8c`.
- 2026-11-14: Phase 6: `first_time_shot` (error x0.6) and `rabona` (no weak-foot penalty) special skills in play. Branch `feature/polish`, commit `16fa679`.
- 2026-11-14: foot-synced kicks (kick animation with the foot); no change to shot numbers recorded. Branch `feature/player-motion`, commit `1983d1f`.
- 2026-11-14: Phase 2: hold to charge, power bar, release to shoot, curl when turning. Branch `feature/core-match` (`main`), commit `19add2a`.

## Do not undo
- Hold to charge and release: power rises with the charge.
- Every accuracy and power effect goes through the stat sheet and `stat_effects.json`; weak foot error grows as stars fall.
- `first_time_shot` and `rabona` effects stay tied to `special_skills` (check `ball_handling.gd`).
- Kicks only with the ball in reach; early requests are queued, not played from a distance.
- AI aim tuning (inside the post, skipped bad-angle shots) came from a measured balance problem; check `MATCH BALANCE` after changing shot numbers.

- After any kick the kicker's body must let the ball through for `kick_pass_through_seconds` 0.15 s (`player.ghost_timer`). Without it a shot or pass played back across his own body bounces off his collision circle (bug found by "shot on target: running along the goal line, the shot heads on goal").
- Every shot is aimed at the goal; a shot must not miss only because the shooter is not facing the goal (user request). The error decides the rest.

## How to check after a change
- CI: `tests/physics_smoke_test.tscn`, `tests/stats_test.tscn`.
- `MATCH BALANCE` line (last record: 4.67 goals, 30.3 shots, 16.2 saves per 150-second match over 6 matches; 3 to 7 goals per match).
- Motion study (a shot seen from the match camera).
- Phone test: charge, release, curl, weak foot, early shot.
