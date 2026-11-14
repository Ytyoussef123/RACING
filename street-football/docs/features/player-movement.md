# Player movement

Last change: 2026-11-14, turning with the ball keeps it (turn touch and walk-to-ball assist) (branch `feature/player-motion`, commit `edf97d2`)

## What it does now
- Movement is done by `PlayerMotion` (pure simulation) from a `PlayerIntent`; human and AI use the same intent.
- Run speed 5.5 m/s, sprint 7.8 m/s, with the ball 0.92 of that (`dribble_speed_factor`). Acceleration 22, deceleration 28 m/s2. Turn speed 720 degrees/s, 540 with the ball.
- Stats scale these through the stat sheet (`Player.stat`): speed, acceleration, balance (turning), dribbling (speed and turning with the ball). Linear from attribute 40 to 99.
- Stamina (energy): sprinting drains it (less with high stamina), below 40 % energy top speed drops (to 85 % when empty), it recovers when not sprinting. Shown as a bar under the human's name tag.
- Players push each other apart (`PlayerCollisions`) and stay inside the court. Players are scaled to their height.
- Stunned players move slower (`stun_move_factor` 0.25).
- Court is 36 x 22 m, a little bigger than the first 30 x 18 (user feedback).

## Where it lives
- Code: `scripts/physics/player_motion.gd` (PlayerMotion): `step`, `top_speed`, `_turn`, `apply_sheet`, `reset`.
- Code: `scripts/physics/player_collisions.gd` (PlayerCollisions): `resolve`.
- Code: `scripts/gameplay/player.gd` (Player): `move`, `stat`, `clamp_to_court`, `_update_energy`, `apply_profile`. `scripts/gameplay/player_intent.gd` (PlayerIntent): move, aim, sprint, `dribble_dir`...
- Numbers: `data/config/player.json` -> `run_speed` 5.5, `sprint_speed` 7.8, `dribble_speed_factor` 0.92, `acceleration` 22, `deceleration` 28, `turn_speed_degrees` 720, `dribble_turn_speed_degrees` 540, `radius` 0.35, `height` 1.75, `stun_move_factor` 0.25, `body_restitution` 0.3.
- Numbers: `data/config/stat_effects.json` -> effects `run_speed_mult`, `sprint_speed_mult`, `acceleration_mult`, `turn_speed_mult`, `dribble_turn_speed_mult`, `dribble_speed_factor`, `stamina_drain`; singles `energy_recover_per_second` 0.04, `low_energy_threshold` 0.4, `low_energy_speed_mult` 0.85, `sprint_drain_min_speed` 1.0.
- Tests: `tests/stats_test.tscn`: faster players cover more ground, stamina. `tests/physics_smoke_test.gd`: "dribble and shot score at +x", "player takes the ball". `tests/match_sim_test.gd`: everyone stays in the court.

## History (newest first)
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
- Open proposal, not done: "heavier movement" (slower turns at full speed), proposed on 2026-11-14, left for the user to decide because it changes how the controls feel. Do not do it without asking.
- Gameplay stays on the flat (x, z) plane (online-ready).

## How to check after a change
- CI: `tests/stats_test.tscn` and `tests/physics_smoke_test.tscn`; no stuck players in `tests/match_sim_test.gd`.
- `MATCH BALANCE` line (shots, saves, goals).
- Motion study images and `MOTION` log lines (`tests/motion_study.gd`).
- Phone test: feel of speed, turns, sprint stamina.
