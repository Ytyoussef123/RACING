# Ball physics

Last change: 2026-11-14, ball rolling matches its drawn size, kick-related code in `ball_handling.gd` adapted (branch `feature/player-motion`, commit `1983d1f`)

## What it does now
- Custom simulation, no Godot RigidBody: gravity, ground bounces, rolling friction, air drag, curve (spin), walls, posts, crossbar, nets. Same result on every phone.
- Pure simulation in `scripts/physics/` (no nodes), so it is testable headless and ready for online sync.
- Ball physics radius is 0.11 m. The ball is drawn 1.5x bigger (`ball_visual_scale`) so it reads on a phone. Physics did not change with the scale. Its rolling animation turns at the speed of the drawn size (since 2026-11-14).
- Cage courts (Concrete Cage, Rooftop Cage) have walls: the ball bounces off the boards. Open Lot and Beach Court have no walls: the ball leaving the court gives OUT and a restart.
- Goals are 3 m wide, 2 m high, 1 m deep with nets; the ball stays in the net, and bounces off posts and crossbar.
- Courts are 36 x 22 m (Concrete Cage). Surfaces per court: Beach Court (sand) slows the ball (friction x1.9, bounce x0.7), Rooftop Cage is a little faster and bouncier (friction x0.9, bounce x1.05). The prediction copy of the ball keeps the surface.
- A prediction copy (`BallPhysics.copy()`) is stepped by the receive assist and the AI.

## Where it lives
- Code: `scripts/physics/ball_physics.gd` (BallPhysics): `step`, `kick`, `place`, `apply_surface`, `copy`, `report_hit`, `is_on_ground`, `horizontal_speed`; `_resolve_ground`, `_apply_rolling`, `_apply_curve`.
- Code: `scripts/physics/court_bounds.gd` (CourtBounds): `resolve` (walls, posts, crossbar, net, OUT event).
- Code: `scripts/gameplay/ball.gd` (Ball): the node, `simulate`, visual scale, rolling rotation, shadow. `scripts/gameplay/goal_detector.gd` (GoalDetector): `check`. `scripts/gameplay/court_builder.gd`: builds the 3D court. `scripts/data/court_data.gd` (CourtData): loads a court (`ball_friction_mult`, `ball_bounce_mult`). `scripts/gameplay/match.gd` applies the surface (`apply_surface`).
- Numbers: `data/config/ball.json` -> `radius` 0.11, `gravity` 9.81, `air_drag` 0.12, `rolling_friction` 1.6, `rolling_drag` 0.25, `stop_speed` 0.05, `ground_restitution` 0.55, `ground_bounce_friction` 0.92, `min_bounce_speed` 0.6, `wall_restitution` 0.7, `post_restitution` 0.6, `net_restitution` 0.15, `curve_accel` 9.0, `curve_ground_factor` 0.25, `spin_decay` 0.8, `max_spin` 1.0.
- Numbers: `data/config/animation.json` -> `ball_visual_scale` 1.5.
- Courts: `data/courts/*.json` (`cage_concrete`, `open_lot`, `rooftop_cage`, `beach_sand`): size, `walls`, `wall_height`, `ball_friction_mult`, `ball_bounce_mult`.
- Tests: `tests/physics_smoke_test.gd`: "rolling ball stops", "ball bounces lower and settles", "side wall bounces the ball", "goal detected at +x", "ball stays in the net", "post bounces the ball back", "shot over the bar is no goal", "open court reports OUT". Sand surface check in `tests/progression_test.tscn` (ball rolls about half as far).

## History (newest first)
- 2026-11-14: the ball's rolling now matches its drawn size (it turned at the physics size before). Part of the player-motion work. Branch `feature/player-motion`, commit `1983d1f`.
- 2026-11-14: court surfaces: `ball_friction_mult` and `ball_bounce_mult` (sand 1.9 / 0.7, rooftop 0.9 / 1.05) for the two new courts, so courts feel different. Branch `feature/progression`, commit `f78448c`.
- 2026-11-14: ball drawn 1.5x bigger than its physics size to read on a phone (look only). Ball hits (ground, wall, post, net) feed the match events channel for sounds and effects. Branch `feature/polish`, commits `cff05f4`, `16fa679`.
- 2026-11-14: courts enlarged from 30 x 18 m to 36 x 22 m (center circle 3 m, goal areas 3.5 x 8 m, goals unchanged) after the user said the pitch felt too small and crowded. Branch `feature/five-v-five`, commit `6055f1d`.
- 2026-11-14: Phase 2: custom ball physics with walls, posts, crossbar, nets, curve; courts Concrete Cage (walls) and Open Lot. Chosen over RigidBody for predictable, JSON-tunable, identical-everywhere behavior. Branch `feature/core-match` (merged into `main`), commit `19add2a`.
- 2026-11-14: Phase 1 setup: `Config` autoload that loads `data/config/*.json`. Branch `feature/phase1-setup` (`main`), commit `3193378`.

## Do not undo
- Custom physics, not RigidBody: predictable, tunable from JSON, same on every phone, ready for online sync.
- The ball is drawn 1.5x bigger than its physics size (`ball_visual_scale`) so it reads on a phone. The rolling animation uses the drawn size. Do not change the physics radius to fix the look.
- Keep `scripts/physics/` free of nodes (pure simulation).
- Surface numbers stay in court data (sand slower, rooftop bouncier); the prediction copy must keep the surface.
- Near-side fence is not drawn (it would hide the play); the physics walls are still there.
- Rename trap: never give a class the name of a Godot built-in (see `CLAUDE.md`).

## How to check after a change
- CI: `tests/physics_smoke_test.tscn` (checks listed above) and `tests/progression_test.tscn` (sand surface).
- `MATCH BALANCE` line of `tests/match_sim_test.gd` (goals, shots, saves; the ball must never stay stuck: "longest stuck ball").
- Screenshot tour and motion study images (ball size and shadow).
- Phone test: both cage and open courts, wall bounces, goals, OUT.
