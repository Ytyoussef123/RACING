# Passing and receiving

Last change: 2026-11-15, pass error depends on the speed mode (branch `feature/speed-modes`, commit `a89cab9`). Before that: 2026-11-14, kick buffer while dribbling: kicks only played with the ball in reach (branch `feature/five-v-five`, commit `1d96a5e`).

## What it does now
- PASS (tap): the ball goes to the teammate on the joystick's side, even if he is not exactly on the line (pass assist). Cone 70 degrees, scored mostly by angle, small penalty for a blocked lane. If nobody is in the cone, the teammate closest to the joystick direction is chosen, up to 120 degrees; beyond that, no pass. The ball goes to where the receiver is running (`pass_lead_factor`).
- THROUGH: ball into the space `through_lead_distance` (4 m) in front of the receiver, mostly toward the opponent goal and partly along his run, kept inside the court.
- Pass speed grows with distance (`pass_speed_base` + `pass_speed_per_meter`, between min and max). Error depends on low pass (PASS) and lofted pass (THROUGH) stats; vision changes the through-pass lead.
- Speed mode: the error is multiplied by x0.85 walking, x1.15 sprinting, x1.2 in a knock-on, for everyone, AI too (`player.json` -> `pace_error_mult_walk`, `pace_error_mult_sprint`, `pace_error_mult_knock_on`; `BallHandling._pace_mult`).
- Receive assist: the pass target runs to the earliest point of the predicted ball path (`BallPhysics.copy()` stepped with walls, 2 s ahead) that he can reach in time, and waits there. The joystick keeps aiming (`PlayerIntent.aim`), so first-time kicks go where you point (forward if the stick is neutral). AI receivers and loose-ball chasers use the same prediction.
- Kicks are only played with the ball within reach (`kick_reach` 1.1 m, ball not higher than `kick_max_ball_height`). A pass, through pass or shot asked a little early is queued (kick buffer, `kick_buffer_seconds` 0.5 s, or 1.2 s while dribbling with the aim chosen at the press) and played when the ball is reached. No kicking from a distance.
- Control switches to the receiver when a pass leaves for a teammate. A pass deflected by the other team stops being a pass (`Possession.touched`).
- On defense the PASS button becomes SWITCH (see `defending.md`).

## Where it lives
- Code: `scripts/gameplay/pass_targeting.gd` (PassTargeting): `choose`, `_score`, `pass_velocity`, `through_velocity`.
- Code: `scripts/gameplay/receive_assist.gd` (ReceiveAssist): `intercept_point`, `apply`.
- Code: `scripts/gameplay/ball_handling.gd` (BallHandling): `_pass`, `_through_pass`, `_queue`, `_play_queued`, `_can_kick`, `_with_error`. `scripts/gameplay/possession.gd` (Possession): `kicked`, `touched`.
- Numbers: `data/config/player.json` -> `pass_*` (`pass_cone_degrees` 70, `pass_assist_max_degrees` 120, `pass_angle_weight` 3.0, `pass_distance_weight` 0.04, `pass_blocked_penalty` 0.8, `pass_speed_base` 6.0, `pass_speed_per_meter` 0.55, `pass_speed_min` 7, `pass_speed_max` 16, `pass_lead_factor` 0.8, `pass_target_min_distance` 1.5, `pass_target_max_distance` 24); `through_*` (`through_lead_distance` 4, `through_forward_weight` 0.6, `through_speed_min` 7, `through_speed_max` 15, ...); `receive_*` (`receive_prediction_seconds` 2.0, `receive_speed_margin` 0.85, `receive_arrive_distance` 0.8, `receive_sprint_distance` 2.5); `kick_reach` 1.1, `kick_buffer_seconds` 0.5, `kick_buffer_dribble_seconds` 1.2, `kick_cooldown` 0.35.
- Numbers: `data/config/stat_effects.json` -> `pass_error_degrees`, `through_error_degrees`, `through_lead_mult`.
- Tests: `tests/physics_smoke_test.gd`: "pass assist: teammate 50 degrees off the line", "pass assist: fallback to the closest direction", "pass assist: no pass backwards past the limit", "receive assist: meeting point is on the ball's path", "receive assist: receiver controls the pass", "through pass: aimed ahead of the receiver", "through pass: speed within limits". `tests/stats_test.tscn`: passing stats.

## History (newest first)
- 2026-11-15: pass error by speed mode (x0.85 walking, x1.15 sprinting, x1.2 knock-on). Why: the user's design of the speed modes. Branch `feature/speed-modes`, commit `a89cab9`.
- 2026-11-14: kicks need the ball within `kick_reach`; a kick asked while the ball is ahead waits up to 1.2 s with the aim chosen at the press, and `DribbleAssist` runs the player onto the ball. User feedback (touch dribbling request). Branch `feature/five-v-five`, commit `1d96a5e`.
- 2026-11-14: receive assist (user request: the receiver needs an assist), first-time kick buffer (0.5 s), THROUGH pass (`through_velocity`), AI receivers use the same intercept prediction, pass assist confirmed good by the user. Why: before, control switched to the receiver but he did not move to the ball, and the joystick (still pointing along the pass) could push him away. Branch `feature/five-v-five`, commit `6055f1d`.
- 2026-11-14: pass assist: cone widened to 70 degrees, angle-weighted score, fallback up to 120 degrees. User asked for passes to reach the teammate roughly in the joystick direction even when not exactly on the line (the user called this an important point). Branch `feature/five-v-five`, commit `6874e1f`.
- 2026-11-14: Phase 3: PASS goes to the best teammate in the joystick direction. Branch `feature/five-v-five`, commit `02cd4ce`.
- 2026-11-14: later commits touching `ball_handling.gd` for other features: stat errors (`d4786b9`), match stats counting passes completed (`f613738`), skill moves (`cff05f4`, `16fa679`), foot-synced touches (`1983d1f`).
- 2026-11-14: Phase 2: simple ground pass in the joystick direction. Branch `feature/core-match` (`main`), commit `19add2a`.

## Do not undo
- The pass goes to the teammate on the joystick's side even if he is not exactly on the line (pass assist). The user called this an important point and said "for the pass, it's good now, I like it". Do not narrow the cone or the fallback without asking.
- The receiver gets a receive assist (user request): he runs to the predicted meeting point while the joystick only aims. Without it the stick could push him away from the ball.
- Kicks are only played with the ball within reach: a pass, through pass or shot asked a little early is queued (kick buffer) and played when the ball is reached. No kicking from a distance.
- A pass deflected by the other team stops being a pass (`Possession.touched`).

## How to check after a change
- CI: `tests/physics_smoke_test.tscn` checks listed above, `tests/stats_test.tscn`.
- `MATCH BALANCE` line, and passes completed in the match stats.
- Phone test: pass toward a teammate off the line, receive a pass with the joystick pushed, a through pass, a pass asked early.
