# Player movement

Last change: 2026-11-15, `PlayerIntent.face` and the `face` parameter of `PlayerMotion.step` (branch `feature/after-pass`, commit `3fc24de`). Before that: 2026-11-15, the user's numbers: sprint 5.8, run 3.5, walk 1.55 (branch `feature/player-speed`, commit `cb137a3`). Before that: 2026-11-15, slower players: sprint 5.5, run 3.9, walk 1.55 (commit `bea4541`). Before that: 2026-11-15, speed modes: walk and knock-on speeds, turning grip by speed, faster stamina recovery when walking (branch `feature/speed-modes`, commits `a89cab9`, `9949e3f`)

## What it does now
- Movement is done by `PlayerMotion` (pure simulation) from a `PlayerIntent`; human and AI use the same intent.
- Walk 1.55 m/s, run 3.5 m/s, sprint 5.8 m/s (since 2026-11-15, the user's numbers; originally 2.2 / 5.5 / 7.8). With the ball 0.92 of that (`dribble_speed_factor`): walk 1.43, run 3.22, sprint 5.34 m/s; knock-on 5.8 m/s (no dribbling slowdown). Acceleration 22, deceleration 28 m/s2. Turn speed 720 degrees/s, 540 with the ball.
- Stats scale these through the stat sheet (`Player.stat`): speed, acceleration, balance (turning), dribbling (speed and turning with the ball). Linear from attribute 40 to 99.
- Facing: `PlayerIntent.face` is where the body looks when it is not where he goes (ZERO = he faces where he moves). It is passed to `PlayerMotion.step(..., face)`. The after-pass jog uses it to face the ball while moving away (see `ai.md`).
- Speed modes: `PlayerMotion.step(delta, move, sprint, dribbling, walk, knock_on)` (plus the `face` parameter, see above). Walk = fixed `walk_speed` 1.55 m/s (1.43 with the ball through `dribble_speed_factor`, scaled by the speed stat) whatever the move length. Run = move length x run speed (unchanged). Sprint as before. Knock-on (with the ball) = full sprint speed x `knock_on_speed_factor` 1.0, without the dribbling slowdown. New `walk_speed()` and `knock_on_speed()`.
- Turning grip by speed: `turn_grip_walk` 1.3 at walking pace, 1.0 at run speed (unchanged), `turn_grip_sprint` 0.6 at full sprint. It scales the part of the acceleration that turns the run (speeding up and slowing down are unchanged) and the facing turn speed (`PlayerMotion._accelerate`, `_grip`, `_turn`). This is the "heavier movement" idea left open before, done by the user's choice (moderate).
- Stamina (energy): sprinting drains it (less with high stamina), below 40 % energy top speed drops (to 85 % when empty), it recovers when not sprinting; walking or standing recovers faster (`walk_recover_mult` 1.6). The knock-on drains like a sprint. Shown as a bar under the human's name tag.
- Players push each other apart (`PlayerCollisions`) and stay inside the court. Players are scaled to their height.
- Stunned players move slower (`stun_move_factor` 0.25) and cannot walk or knock-on.
- Court is 36 x 22 m, a little bigger than the first 30 x 18 (user feedback).

## Where it lives
- Code: `scripts/physics/player_motion.gd` (PlayerMotion): `step`, `top_speed`, `walk_speed`, `knock_on_speed`, `_accelerate`, `_grip`, `_turn`, `apply_sheet`, `reset`.
- Code: `scripts/physics/player_collisions.gd` (PlayerCollisions): `resolve`.
- Code: `scripts/gameplay/player.gd` (Player): `move`, `stat`, `clamp_to_court`, `_update_energy`, `apply_profile`. `scripts/gameplay/player_intent.gd` (PlayerIntent): move, aim, sprint, `walk`, `knock_on`, `dribble_dir`...
- Numbers: `data/config/player.json` -> `run_speed` 3.5, `sprint_speed` 5.8, `dribble_speed_factor` 0.92, `acceleration` 22, `deceleration` 28, `turn_speed_degrees` 720, `dribble_turn_speed_degrees` 540, `radius` 0.35, `height` 1.75, `stun_move_factor` 0.25, `body_restitution` 0.3, and since 2026-11-15 `walk_speed` 1.55, `turn_grip_walk` 1.3, `turn_grip_sprint` 0.6, `knock_on_speed_factor` 1.0 (knock-on = 5.8 m/s, follows the sprint).
- Numbers: `data/config/stat_effects.json` -> effects `run_speed_mult`, `sprint_speed_mult`, `acceleration_mult`, `turn_speed_mult`, `dribble_turn_speed_mult`, `dribble_speed_factor`, `stamina_drain`; singles `energy_recover_per_second` 0.04, `low_energy_threshold` 0.4, `low_energy_speed_mult` 0.85, `sprint_drain_min_speed` 1.0, `walk_recover_mult` 1.6.
- Tests: `tests/physics_smoke_test.gd`: "turning grip: a sprinting player turns wider than a walking one". `tests/stats_test.tscn`: faster players cover more ground, stamina. `tests/physics_smoke_test.gd`: "dribble and shot score at +x", "player takes the ball". `tests/match_sim_test.gd`: everyone stays in the court.

## History (newest first)
- 2026-11-15: new `PlayerIntent.face` and a `face` parameter in `PlayerMotion.step`: the body can look at a point other than where he moves (ZERO = as before). Movement numbers unchanged. Why: after a pass the player jogs backward while facing the ball (user request, see `ai.md`). Branch `feature/after-pass`, commit `3fc24de`.
- 2026-11-15: the user's own numbers: `sprint_speed` 5.5 -> 5.8, `run_speed` 3.9 -> 3.5 (walk stays 1.55; knock-on follows the sprint = 5.8). With the ball: run 3.22, sprint 5.34. `ai.json` `through_min_runner_speed` 2.1 -> 1.9; motion study poses jog 2.6, sprint 5.6; code fallbacks updated. Why: the user: "the sprint can be 5.8 and run 3.5". Balance (6 AI matches, with the PRESS fix): 4.17 -> 2.33 goals, 23.8 -> 17.3 shots, 13.5 -> 11.0 saves; the drop comes from the slower run, not retuned (the user decides). Branch `feature/player-speed`, commit `cb137a3` (CI run 43756796940 green; phone test pending).
- 2026-11-15: players slower: `sprint_speed` 7.8 -> 5.5 m/s (the old run speed), `run_speed` 5.5 -> 3.9, `walk_speed` 2.2 -> 1.55 (all x0.705, same proportions); knock-on follows the sprint (5.5). Unchanged on purpose: acceleration 22, deceleration 28, turn speeds, turn grips, stat effects, AI `speed_factor`. Tests: dribble checks in `tests/physics_smoke_test.gd` now compare the steps to each other. Why: user request: "The speed of player should be reduced. Now normally the speed without the sprint button should be the speed with sprint, and the without should be less." Balance (6 AI matches): 4.83 -> 4.17 goals, 27.5 -> 23.8 shots, 17.3 -> 13.5 saves; balls won 160 -> 93. Branch `feature/player-speed`, commit `bea4541` (CI run 43738218282 green; phone test pending).
- 2026-11-15: speed modes: `PlayerIntent.walk` / `knock_on`, fixed walking speed, knock-on at full sprint speed, turning grip by speed (sharper walking, wider sprinting), walking recovers stamina faster. Why: the user's design of four speeds with the ball (walk, run, sprint, knock-on); they chose a moderate "heavier movement". Branch `feature/speed-modes`, commits `a89cab9`, `9949e3f`.
- 2026-11-14: turning with the ball keeps it: new `PlayerIntent.dribble_dir` carries the wanted direction while the player walks to the ball. Why: the ball was left at his side in turns (found in the CI motion study). Branch `feature/player-motion`, commit `edf97d2`.
- 2026-11-14: new jointed body and running animation: the body turns hips toward the way he goes so feet do not slide; movement numbers unchanged. Branch `feature/player-motion`, commit `1983d1f`.
- 2026-11-14: Phase 6 changed `player.gd` / `player_motion.gd` for animation and skill moves, with no change to the movement numbers. Branch `feature/polish`, commits `cff05f4`, `16fa679`.
- 2026-11-14: Phase 4: attributes drive speed, acceleration, turning, stamina through `stat_effects.json`; stamina (energy) added; players scaled to real height. Branch `feature/player-stats`, commit `d4786b9`.
- 2026-11-14: `Player.strength` (`default_strength` 50) for shoulder duels (user's shoulder-charge request); while stunned (`Player.stun_timer`, after a missed tackle or a lost shoulder duel), the player moves at `stun_move_factor` (0.25) of his speed and cannot sprint (`scripts/gameplay/player.gd`, `move()`). Branch `feature/five-v-five`, commits `1d96a5e`, `6055f1d`, `6874e1f`.
- 2026-11-14: user asked for a slightly bigger pitch ("quite bigger, not a lot"): 30 x 18 -> 36 x 22 m. Branch `feature/five-v-five`, commit `6055f1d`.
- 2026-11-14: Phase 3: players push each other apart (`PlayerCollisions`). Branch `feature/five-v-five`, commit `02cd4ce`.
- 2026-11-14: Phase 2: acceleration, sprint, turning (`PlayerMotion`). Branch `feature/core-match` (`main`), commit `19add2a`.

## Do not undo
- `PlayerIntent` is the only input of a player: the AI obeys the same rules as the human.
- Movement numbers come from `player.json`, scaled only through the stat sheet; no magic numbers in code.
- The speed steps (walk, run, sprint, knock-on) are the user's design (2026-11-15). The AI still gives analog moves (no walk flag) until the AI work, planned after the user's controls test.
- Player speeds were lowered at the user's request (2026-11-15): sprint 5.8 m/s, run 3.5, walk 1.55 (the user's numbers: "the sprint can be 5.8 and run 3.5"). Do not raise them without asking.
- "Heavier movement" (turning grip by speed) was proposed on 2026-11-14 and done on 2026-11-15 by the user's choice (moderate). Do not make it stronger without asking.
- Gameplay stays on the flat (x, z) plane (online-ready).

## How to check after a change
- CI: `tests/stats_test.tscn` and `tests/physics_smoke_test.tscn`; no stuck players in `tests/match_sim_test.gd`.
- `MATCH BALANCE` line (shots, saves, goals).
- Motion study images and `MOTION` log lines (`tests/motion_study.gd`).
- Phone test: feel of speed, turns, sprint stamina.
