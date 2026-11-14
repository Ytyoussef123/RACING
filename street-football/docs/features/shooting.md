# Shooting

Last change: 2026-11-14, shots asked early or while the ball is ahead wait for the ball (kick buffer); later commits only touched the same files for other features (branch `feature/five-v-five`, commit `1d96a5e`)

## What it does now
- SHOOT: hold to charge (`shot_charge_time` 0.9 s, power bar above the player), release to shoot. Speed between `shot_speed_min` 12 and `shot_speed_max` 26 m/s, lift between 0.5 and 5.5. Turning while shooting curls the ball (`shot_curve_from_turn`).
- Stats: shot power scales the speed (`shot_speed_mult`); finishing sets the aim error (`shot_error_degrees`); long shots add error per meter beyond `long_shot_distance` 12 m (`long_shot_error_per_meter`).
- Weak foot: a kick aimed well to the weak side (more than `weak_side_degrees` 35 off the facing) has more error, by weak-foot stars (`weak_foot_error_mult` [2.6, 2.0, 1.5, 1.15] for 1 to 4 stars).
- Special skills: `first_time_shot` makes a one-touch shot (the shooter does not hold the ball) more accurate (error x0.6, `skills.json` -> `first_time_shot_error_mult`); `rabona` removes the weak-foot penalty.
- A shot needs the ball within `kick_reach`; a shot asked early is queued (kick buffer) and played when the ball is reached; the aim is chosen at the press.
- On defense the SHOOT button becomes TACKLE; the earlier version (PRESS on this button) was replaced (see `defending.md`).
- The AI shoots in range (aims at the corner away from the keeper with a difficulty-based error). Match stats count shots.

## Where it lives
- Code: `scripts/gameplay/ball_handling.gd` (BallHandling): `_shoot`, `_with_error`, `_weak_foot_mult`, `_kick`, `_aim_direction`, `_queue`, `_play_queued`. The charge and release come from `PlayerIntent` (`scripts/gameplay/player_intent.gd`) filled by `HumanInput`/touch controls.
- Code: `scripts/physics/ball_physics.gd` (BallPhysics): `kick(velocity, spin)`, curve.
- Numbers: `data/config/player.json` -> `shot_charge_time`, `shot_speed_min`, `shot_speed_max`, `shot_lift_min`, `shot_lift_max`, `shot_curve_from_turn`, `kick_reach`, `kick_max_ball_height`, `kick_cooldown`, `kick_buffer_seconds`.
- Numbers: `data/config/stat_effects.json` -> `shot_speed_mult`, `shot_error_degrees`, `long_shot_error_per_meter`, `long_shot_distance`, `weak_side_degrees`, `weak_foot_error_mult`. `data/config/skills.json` -> `first_time_shot_error_mult`. `data/config/controls.json` -> `shoot_position`, `shoot_radius`.
- Numbers (AI): `data/config/ai.json` (shot range, aim and error per difficulty).
- Tests: `tests/physics_smoke_test.gd`: "dribble and shot score at +x", "shot over the bar is no goal". `tests/stats_test.tscn`: finishing, shot power, long shots, weak foot. `tests/match_sim_test.gd` (shots in `MATCH BALANCE`).

## History (newest first)
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

## How to check after a change
- CI: `tests/physics_smoke_test.tscn`, `tests/stats_test.tscn`.
- `MATCH BALANCE` line (last record: 5.00 goals, 28.3 shots, 11.0 saves per 150-second match; with only 3 matches the goal count moves a lot).
- Motion study (a shot seen from the match camera).
- Phone test: charge, release, curl, weak foot, early shot.
