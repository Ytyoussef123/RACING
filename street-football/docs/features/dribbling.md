# Dribbling

Last change: 2026-11-14, the "last touch was a sprint knock" flag is set by touches only (branch `feature/player-motion`, commit `1690191`)

## What it does now
- Touch dribbling: when moving, the dribbler knocks the ball ahead and catches up with it; a dribbled ball slows faster (`dribble_ball_friction`) so it stays close.
- Extra touch speed over his own: 1.2 m/s slow, 1.7 running, 4.5 sprinting. Jog: ball about 0.3 to 1.0 m ahead, a touch about every 0.3 s. Sprint: knocked 1.5 to 3 m ahead.
- Every touch is done by a foot (the one on the ball's side, otherwise the preferred foot). The foot starts its swing 0.1 s before the ball is in reach (`dribble_touch_windup`) and touches start at the predicted reach, so foot and ball meet.
- Joystick released or standing: the ball is stopped and kept at the feet (held a little closer).
- Turning: the touch is aimed at where the player will be once turned. If the ball is out of reach when the stick turns, `DribbleAssist` walks him to it first, keeping the wanted direction in `PlayerIntent.dribble_dir`.
- Ball lost if it goes beyond `dribble_leash` (2.4 m, 3.6 m sprinting). After a long sprint knock the ball stays his while he chases it (sprint leash until his next touch), even if he lets go of SPRINT or starts a shot.
- A ball knocked beyond `dribble_exposed_distance` (0.8 m, scaled by tight possession) can be stolen by a closer opponent; at his feet it is safe.
- Kicks need the ball within reach: with the ball ahead, a pass/through/shot waits (kick buffer) and `DribbleAssist` runs the player onto the ball. Same for the AI.
- Stats: dribbling changes touch distance, speed and turning with the ball; tight possession changes the exposed distance.

## Where it lives
- Code: `scripts/gameplay/dribbling.gd` (Dribbling): `update`, `_touch`, `_turn_touch`, `_foot`, `_hold_at_feet`, `_slow_ball`, `can_steal` (static). Flag `_long_touch`, timers `_touch_timer`, `_windup`.
- Code: `scripts/gameplay/dribble_assist.gd` (DribbleAssist): `adjust`, `_turn_to_ball`.
- Code: `scripts/gameplay/ball_handling.gd` (BallHandling): delegates to `Dribbling`; kick queue (`_queue`, `_play_queued`), `_try_take`. `scripts/gameplay/possession.gd` (Possession): one holder at a time.
- Numbers: `data/config/player.json` -> `dribble_*` (reach, touch, turn, leash, steal), plus `dribble_speed_factor` 0.92, `kick_reach` 1.1, `kick_buffer_dribble_seconds` 1.2. Main values: `dribble_distance` 0.48, `dribble_touch_reach` 0.75, `dribble_touch_interval` 0.2, `dribble_touch_extra_min` 1.2, `dribble_touch_extra_run` 1.7, `dribble_touch_extra_sprint` 4.5, `dribble_touch_windup` 0.1, `dribble_windup_reach_margin` 1.3, `dribble_foot_side_offset` 0.12, `dribble_turn_reach` 0.85, `dribble_turn_assist_degrees` 50, `dribble_turn_touch_time` 0.3, `dribble_turn_touch_lead` 0.6, `dribble_turn_touch_max_speed` 9.0, `dribble_ball_friction` 3.0, `dribble_stop_friction` 8.0, `dribble_leash` 2.4, `dribble_leash_sprint` 3.6, `dribble_exposed_distance` 0.8, `dribble_steal_cooldown` 0.4.
- Numbers: `data/config/stat_effects.json` -> `dribble_touch_extra_mult`, `dribble_exposed_distance`, `dribble_speed_factor`, `dribble_turn_speed_mult`.
- Tests: `tests/physics_smoke_test.gd`: "touch dribble: keeps the ball when running", "...several touches, ball goes ahead", "...keeps the ball when sprinting", "...sprint touches push the ball further", "steal: ball knocked ahead is taken by the closer opponent", "steal: ball at the dribbler's feet is safe". `tests/stats_test.tscn`: better dribblers touch closer. `tests/motion_study.gd`: `MOTION` lines.

## History (newest first)
- 2026-11-14: the sprint-knock flag is set only by touches; docs for player motion. First version cleared it whenever the ball was within reach, which happened the frame right after the sprint touch, so it never worked. Branch `feature/player-motion`, commit `1690191`.
- 2026-11-14: a sprint knock-on stays yours until you catch it (sprint leash until his next touch, even if SPRINT is released or a shot starts). Branch `feature/player-motion`, commit `200f7ee`.
- 2026-11-14: turning with the ball keeps it: turn touch aimed at where the player will be, `DribbleAssist` walks to the ball first, `PlayerIntent.dribble_dir`. Why: the CI motion study showed the ball left at his side and lost in turns. Branch `feature/player-motion`, commit `edf97d2`.
- 2026-11-14: every touch done by a foot, wind-up 0.1 s, jog touches closer (`dribble_touch_extra_min` 1.6 -> 1.2, `dribble_touch_extra_run` 2.6 -> 1.7, `dribble_distance` 0.55 -> 0.48). Why: the user compared with a video of the reference game (how the ball reacts at the feet while running); the old values made the ball run 0.74 to 1.34 m ahead and the player looked like he was chasing it. Branch `feature/player-motion`, commit `1983d1f`.
- 2026-11-14: Phase 6 and 4 changes to files of this feature (skill moves play the ball to himself, stat effects on touches, match stats counters). Branches `feature/polish`, `feature/player-stats`, commits `cff05f4`, `16fa679`, `f613738`, `d4786b9`.
- 2026-11-14: touch dribbling replaces the ball glued to the feet; kicks need the ball within `kick_reach`; `DribbleAssist` added. User feedback (Phase 3): the player should tap the ball ahead and catch it, harder when sprinting. Branch `feature/five-v-five`, commit `1d96a5e`.
- 2026-11-14: first-time buffer and receive changes touching `ball_handling.gd`. Branch `feature/five-v-five`, commit `6055f1d`.
- 2026-11-14: Phase 3: `Possession` (one holder at a time). Branch `feature/five-v-five`, commit `02cd4ce`.
- 2026-11-14: Phase 2: ball kept in front of the player (`dribble_distance`, `dribble_stiffness`). Branch `feature/core-match` (`main`), commit `19add2a`.

## Do not undo
- Touch dribbling (ball knocked ahead and caught again) replaced a ball glued to the feet, at the user's request (Phase 3 feedback: taps, harder when sprinting). Do not go back to a glued ball.
- The foot starts its swing 0.1 s before the touch (`dribble_touch_windup`) and touches start at the predicted reach, so foot and ball meet.
- Jog touches stay low (`dribble_touch_extra_min` 1.2, `dribble_touch_extra_run` 1.7): with the old 1.6 / 2.6 the ball ran 0.74 to 1.34 m ahead and the player looked like he was chasing it.
- Turning: aim the touch at where the player will be once turned; if the ball is out of reach when the stick turns, `DribbleAssist` walks him to it first, keeping the wanted direction in `PlayerIntent.dribble_dir`. Before that the ball was left at his side and lost in turns.
- The "last touch was a sprint knock" flag (`_long_touch`, sprint leash kept while chasing) must be set only by touches. A first version cleared it whenever the ball was within reach, which happened the frame right after the sprint touch, so it never worked.
- A ball knocked ahead beyond `dribble_exposed_distance` can be stolen; a ball at the feet is safe.
- `BallHandling` delegates dribbling to `Dribbling` (small files).

## How to check after a change
- Motion study images (jog and sprint with the ball, turn) and `MOTION` log lines (ball distance ahead of the player per frame), from `tests/motion_study.gd`: jog about 0.3 to 1.0 m, sprint 1.5 to 3 m, no ball left at the side in a turn.
- CI: `tests/physics_smoke_test.tscn` dribble and steal checks, `tests/stats_test.tscn`.
- `MATCH BALANCE` line (players keeping the ball longer gave more shots: 5.00 goals, 28.3 shots, 11.0 saves at last record).
- Phone test: running, sprinting, turning with the ball.
