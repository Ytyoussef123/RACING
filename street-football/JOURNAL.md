# Street Football 5v5: Journal

A dated log, newest entry first: what was done, what was decided and why, and what is next.

## Phases

| # | Phase | Status |
|---|---|---|
| 1 | Setup | Done, tested on phone (2026-11-14) |
| 2 | Core match: court, ball physics, one controllable player, touch controls, shooting | Done, tested on phone (2026-11-14) |
| 3 | 5v5: teams, goalkeepers, formations, basic AI, score, timer | Done, waiting for phone test |
| 4 | Player stats: data files, attributes affect gameplay, 30 fictional players | Not started |
| 5 | Menus and UI: main menu, team/formation, court selection, results, translations | Not started |
| 6 | Skills and polish: skill moves, animations, sounds, music, effects, wall bounces | Not started |
| 7 | Progression: coins, unlocks, upgrades, save system | Not started |
| 8 | Release build: optimized APK, full file review | Not started |

## Log

### 2026-11-14 — Phase 3: touch dribbling and shoulder charge (user feedback)

#### Feedback

- The user asked (like eFootball) for a shoulder charge: double-tap the joystick near the ball carrier to push him with the shoulder, later based on each player's physical strength. They also asked for realistic dribbling: the player taps the ball ahead and catches it, and taps harder when sprinting, instead of the ball being glued to the foot.

#### Done

- Shoulder charge (`scripts/gameplay/shoulder_charge.gd`): double-tap the joystick when your side does not have the ball. `FloatingStick` detects two short taps close together within `double_tap_seconds` (0.3 s); keyboard F.
  - Within `shoulder_reach` (1.4 m) of the carrier: win the duel and the carrier is pushed, off balance (`shoulder_victim_stun`), can't retake the ball for a moment, and the ball comes loose. Lose and the charger bounces off and is slowed.
  - Too far: a small lunge and a short slowdown.
  - Chance = `shoulder_base_chance` 0.5 + strength difference x `shoulder_strength_factor` 0.01, clamped 0.15 to 0.85. `Player.strength` = `default_strength` 50 for everyone until the Phase 4 stats.
  - The keeper is protected in his goal area. Works together with PRESS.
- Touch dribbling (`scripts/gameplay/dribbling.gd`): when moving, the dribbler knocks the ball ahead (extra speed over his own: about 1.6 m/s slow, 2.6 running, 4.5 sprinting) and catches up with it. A dribbled ball slows faster (`dribble_ball_friction`) so it stays close. With the joystick released the ball is stopped and kept at the feet. Measured in tests: about 0.9 m ahead when running, about 1.8 m when sprinting.
  - The ball is lost if it gets beyond `dribble_leash` (2.4 m, 3.6 m sprinting). A ball knocked more than `dribble_exposed_distance` (0.8 m) ahead can be stolen by an opponent who is closer to it.
- Kicks now need the ball within `kick_reach` (1.1 m). A pass, through pass or shot asked while the ball is ahead waits (up to `kick_buffer_dribble_seconds` 1.2 s, with the aim chosen when pressing) and `DribbleAssist` (`scripts/gameplay/dribble_assist.gd`) runs the player onto the ball to play it. With the joystick released he goes to stop the ball. Same rules for the AI.
- `BallHandling` now delegates dribbling to `Dribbling` (keeps files small).
- CI green: 27 physics tests (new: touches run vs sprint, steal of a ball knocked ahead vs safe at the feet, shoulder duel about 50 % at equal strength, out of reach does nothing, stronger player has more chance). AI-vs-AI match ended 2-1, longest still loose ball 0.8 s.

#### Next

- User tests on the phone. Then merge `feature/five-v-five` into `main` and propose the Phase 4 plan (stats will drive strength, dribbling, speed and more).

### 2026-11-14 — Phase 3: eFootball button layout, receive assist, bigger court (user feedback)

#### Feedback

- The user sent eFootball screenshots. PRESS must be available whenever you don't have the ball, on the same button as SPRINT (eFootball "Dash & Press"). The player receiving a pass needs an assist. The pitch felt too small and crowded ("quite bigger, not a lot"). The pass assist was confirmed good.

#### Done

- Four buttons in an eFootball-style diamond (`data/config/controls.json`):

| Position | Attack | Defense |
|---|---|---|
| Top-left | THROUGH | MATCH-UP |
| Top-right | SHOOT | TACKLE |
| Bottom-left | PASS | SWITCH |
| Bottom-right | SPRINT | PRESS |

- Labels and meaning switch with possession (`HumanControl.is_attacking`): attack layout when our side holds the ball or touched the loose ball last (our pass or shot travelling), defense layout otherwise. The separate SWITCH button was removed: SWITCH is now the PASS button on defense (Q on keyboard). Keyboard keys follow the same positions: R, Space, E, Shift.
- PRESS (hold SPRINT on defense, `scripts/gameplay/press_assist.gd`): sprints goal-side of the carrier, then to the ball, auto-tackles in reach. On a loose ball it sprints to where the player can meet it.
- MATCH-UP (hold, `scripts/gameplay/match_up_assist.gd`): shadows the carrier goal-side at `match_up_contain_distance` (1.6 m) and follows his moves. No auto tackle (tap TACKLE).
- Receive assist (`scripts/gameplay/receive_assist.gd`): the pass target runs to the earliest point of the predicted ball path (`BallPhysics.copy()` stepped with walls, 2 s ahead) he can reach in time, and waits there. The joystick keeps aiming (`PlayerIntent.aim`), so first-time kicks go where you point (forward if the stick is neutral). Before, control switched to the receiver but he did not move to the ball, and the joystick (still pointing along the pass) could push him away.
- First-time buffer (`BallHandling`): PASS, THROUGH or a shot released up to `kick_buffer_seconds` (0.5 s) before the ball arrives is kept and played when the ball comes within reach.
- THROUGH pass (`PassTargeting.through_velocity`): into the space `through_lead_distance` (4 m) in front of the receiver, mostly toward the opponent goal and partly along his run, kept inside the court.
- AI receivers and loose-ball chasers now use the same intercept prediction. A pass deflected by the other team stops being a pass (`Possession.touched`). Tackling when nobody has the ball no longer stuns.
- Courts are now 36 x 22 m (was 30 x 18): center circle 3 m, goal areas 3.5 x 8 m. Goals unchanged (3 x 2 m).
- CI green: 18 physics tests pass (new: receive assist meets a pass rolling past the receiver even with the joystick pushed along the pass; through pass aimed ahead of the receiver). AI-vs-AI match on the bigger court ended 2-1, 3 goals, ball never stuck.

#### Next

- User tests on the phone. Then merge `feature/five-v-five` into `main` and propose the Phase 4 plan.

### 2026-11-14 — Phase 3: PRESS button and pass assist (user feedback)

#### Done

- The user asked (like eFootball) for a button that makes the selected player go and win the ball from the opponent, and for passes to reach the teammate roughly in the joystick direction even when not exactly on the line.
- PRESS: on defense (opponent has the ball) SHOOT becomes PRESS. Hold it and the player runs goal-side of the ball carrier at sprint speed, then goes for the ball and tackles by himself when in reach (`scripts/gameplay/press_assist.gd`; `press_*` keys in `data/config/player.json`). PASS still becomes TACKLE.
- Pass assist (`scripts/gameplay/pass_targeting.gd`): cone widened to 70 degrees; the choice is scored mostly by angle (`pass_angle_weight` 3.0, `pass_distance_weight` 0.04), with a small penalty for a blocked lane (`pass_blocked_penalty` 0.8). If nobody is in the cone, the teammate closest to the joystick direction is chosen, up to 120 degrees (`pass_assist_max_degrees`). The ball still goes to where the receiver is running.
- New physics tests for the pass assist: 50 degrees off the line, fallback, nothing past 120 degrees. CI green.

#### Next

- User tests on the phone, then the rest of the Phase 3 feedback.

### 2026-11-14 — Phase 3: 5v5

#### Done

- Branch `feature/five-v-five`. CI green on the first run: physics tests all pass, and the new headless AI-vs-AI match test (`tests/match_sim_test.tscn`, 150 s match at fixed 60 fps) ended 4–2 with 6 goals counted, the ball never stuck and everyone staying in the court. Not yet tested on the phone.
- Start screen: Formation button (cycles 2-1-1, 1-2-1, 1-1-2, 2-2, 1-1-1-1), Difficulty button (Easy / Normal / Hard), "Play — Concrete Cage", "Play — Open Lot", language button.
- Match: your team orange (keeper yellow) attacks to the right; AI team cyan (keeper purple), formation 1-2-1. Score and 3:00 clock at the top, court name under it, MENU top-left, formation button top-right (changes your formation during the match). Kick-off by the team that conceded. FULL TIME message with the score, then back to the start screen after 4 s. Open Lot: KICK-IN, CORNER or GOAL KICK after the ball goes out (team that did not touch it last).
- Controls: joystick, SHOOT (hold), PASS (goes to the best teammate in the joystick direction; becomes TACKLE when an opponent has the ball), SPRINT, SWITCH (jump to the teammate nearest the ball). Automatic switch: when a pass leaves for a teammate, when a teammate gets the ball, and when defending if a teammate is clearly closer. Goalkeepers are always AI. Keyboard: E pass/tackle, Q switch (plus the earlier keys).
- Rules: one player controls the ball at a time; a tackle in reach has a chance to knock the ball loose, a miss slows the tackler briefly; a keeper holding the ball in his goal area can't be tackled; players push each other apart.
- AI: the team brain picks a chaser (closest outfield player) and does greedy marking in its half. The ball carrier shoots in range (aims at the corner away from the keeper, with a difficulty-based error), passes when pressed or when a teammate is open further up with a clear lane, else dribbles around defenders. Off-ball players hold formation slots that shift with the ball and step away from defenders to get open. The keeper stays between ball and goal, moves across for shots, rushes loose balls near goal, saves (catch or parry) once per shot with a difficulty-based chance, then passes to the most open teammate. Your teammates use "normal".
- Data: `data/formations/*.json` (slot role + x 0..1 from own goal + z −1..1); `data/config/ai.json` (difficulties + positioning/decision numbers); new `player.json` keys (`tackle_*`, pass targeting); `match.json` (match length, colors, switching, restarts, formation and difficulty lists).
- New code: `scripts/ai/` (`team_brain`, `carrier_ai`, `support_ai`, `keeper_ai`, `formation_positions`, `steering`, `ai_tuning`, `ai_player_state`), `scripts/gameplay/` (`team`, `team_factory`, `possession`, `match_context`, `match_flow`, `restart_placer`, `human_control`, `pass_targeting`, `tackle_rules`), `scripts/physics/player_collisions.gd`, `scripts/data/formation_data.gd`.

#### Decisions (and why)

- **Every player (human or AI) is driven by the same `PlayerIntent`:** the AI obeys the same rules as the human.
- **AI decisions run at a difficulty-based interval (reaction time), movement runs every frame:** difficulty is tunable and movement stays smooth.
- **One shared `Possession` object:** only one player can control the ball at a time.
- **Keepers always AI:** usual in street football games, and it keeps the controls simple.
- **A full AI match runs in CI:** it catches stuck balls and broken rules before the phone test.

Known: at the start of the CI import Godot logs "Cannot open file strings.en.translation" once, because the translation files are generated during that import. Harmless.

#### How to test

- Download the `feature/five-v-five` branch ZIP, import `street-football/project.godot` in Godot on the phone and run, or install the APK from the GitHub Actions run.
- Try the formations and the three difficulties on both courts: score, concede (kick-off by the team that conceded), tackle, pass, SWITCH and automatic switching, change formation with the top-right button, play to FULL TIME, send the ball out on Open Lot.

#### Next

- Phone test and feedback (tuning goes in `data/config/ai.json`).
- Then merge `feature/five-v-five` into `main`.
- Then the Phase 4 plan (player stats), to be agreed before starting.

### 2026-11-14 — Phase 2 tested on the phone

#### Done

- The user tested Phase 2 on the phone and answered "Good".
- Before that, CI caught two bugs that broke the match scene (the physics tests passed every time):
  - Helper methods named `draw()` clashed with the CanvasItem `draw` signal, so they were renamed to `render()`.
  - `class_name VirtualJoystick` is hidden by Godot 4.7's built-in `VirtualJoystick` class, so it was renamed to `FloatingStick` (`scripts/ui/floating_stick.gd`). `TouchButton` was renamed to `ActionButton` (`scripts/ui/action_button.gd`) for safety.
- The rule against these naming traps was added to `CLAUDE.md`.
- CI now prints each distinct error once.

#### Next

- Merge `feature/core-match` into `main`.
- Then propose the Phase 3 plan (5v5) and wait for the user's OK.

### 2026-11-14 — Phase 2: core match

#### Done

- Branch `feature/core-match`. Not yet tested on the phone.
- Start screen: two buttons, "Play — Concrete Cage" (walls on, the ball bounces off the boards) and "Play — Open Lot" (no walls: the ball leaving the court shows OUT and restarts), plus the language button.
- Match: 3D low-poly court 30 x 18 m, small goals (3 m wide, 2 m high, 1 m deep, with nets), fixed camera at 55 degrees following the ball. One controllable player (orange capsule, yellow ring) and one ball. GOAL! message, then kick-off from the center after 2 s; OUT after 1.5 s. MENU button top-left returns to the start screen. Court name shown top center.
- Touch controls: floating joystick on the left; right side SHOOT (hold to charge, power bar above the player, release to shoot, turning while shooting curls the ball), PASS (tap, ground pass in the joystick direction), SPRINT (hold). Keyboard on PC: WASD/arrows, Shift, Space (hold), E.
- Ball physics: gravity, ground bounces, rolling friction, air drag, curve (spin), walls, posts, crossbar, nets. Player: acceleration, sprint, turning, dribbling (ball kept in front); the ball bounces off the body when not controlled.
- Every number is in `data/config/`: `ball.json`, `player.json`, `camera.json`, `controls.json`, `match.json`. Courts in `data/courts/cage_concrete.json` and `data/courts/open_lot.json`. New autoload `MatchSetup` (`scripts/core/match_setup.gd`) holds the chosen court.
- Code layout: `scripts/physics/` (`ball_physics.gd`, `court_bounds.gd`, `player_motion.gd`: pure simulation, no nodes, so it is testable and ready for online play), `scripts/gameplay/` (`ball.gd`, `player.gd`, `ball_handling.gd`, `goal_detector.gd`, `player_intent.gd`, `human_input.gd`, `court_builder.gd`, `match_camera.gd`, `match.gd`), `scripts/ui/` (`touch_controls.gd`, `floating_stick.gd`, `action_button.gd`, `match_hud.gd`, `boot_screen.gd`), `scripts/data/court_data.gd`.
- CI (GitHub Actions) now also runs headless physics tests (`tests/physics_smoke_test.tscn`, excluded from the APK) and runs the match scene, before exporting the APK.

#### Decisions (and why)

- **Custom ball physics instead of Godot's RigidBody:** predictable, tunable from JSON, same result on every phone, easier to sync online later.
- **`PlayerIntent` is the single input format:** the Phase 3 AI will drive players the same way as the human.
- **Touch controls handle every finger themselves:** reliable multi-touch.
- **Near-side fence not drawn:** it would hide the play (the physics walls are still there).
- **Blob shadows instead of real shadows:** cheap on phones and they show the ball height.

#### How to test

- Open Godot on the phone, re-download the branch ZIP `feature/core-match`, import `street-football/project.godot`, run.
- Try both courts (Concrete Cage and Open Lot): move, sprint, dribble, shoot (charge and release, with a curl), pass, score a goal, send the ball out, use MENU.

#### Next

- Phone test.
- Then merge `feature/core-match` into `main`.
- Then the Phase 3 plan (5v5: teams, goalkeepers, formations, basic AI), to be agreed before starting.

### 2026-11-14 — Phase 1 tested on the phone

#### Done

- The user downloaded the branch ZIP, imported `street-football/project.godot` in the Godot 4.7 Android editor and ran it directly on the phone (the editor's run button).
- Result: landscape OK, title and orange stripe shown, tap counter works, French translation works ("Touches : 17", "Langue : Français"), FPS counter shows 60, device info shows Android and Godot 4.7-stable.

#### Decisions (and why)

- **Running the project inside the Godot Android editor is an accepted quick way to test each phase on the phone.**
- The APK built by GitHub Actions is still to be verified: no workflow run has appeared yet.

#### Next

- Merge `feature/phase1-setup` into `main`.
- Propose the Phase 2 plan (core match) and wait for the user's OK.

### 2026-11-14 — Phase 1: project setup

#### Done

- Godot 4.7 project in `street-football/`, a subfolder of the RACING repository, which also contains Corniche Rush (the user chose to keep both games in one repo).
- Folder structure (see `CLAUDE.md`).
- `Config` autoload (`scripts/core/config.gd`) loading `data/config/*.json`, and `FrameRate` autoload applying `performance.json` (60 FPS target; 30 FPS fallback stored for Phase 8).
- Boot test screen: `scenes/boot/boot_screen.tscn` + `scripts/ui/boot_screen.gd` (tap counter, EN/FR switch, FPS counter, device info).
- Translations in `locale/strings.csv`.
- Android export preset: arm64-v8a, immersive, sensor landscape, package `com.streetfootball.fivevfive`, includes `*.json`.
- GitHub Actions workflow that imports the project, runs the scene headless to catch script errors, and exports a debug APK as an artifact.
- Shared debug keystore `.github/keystore/debug.keystore` so CI builds install over each other.
- `CLAUDE.md` (project rules and model table) and subagents `docs-writer` and `code-reader` in `.claude/agents/` (Sonnet, medium effort).
- `docs/android-export.md` and `docs/design-decisions.md`.

#### Decisions (and why)

- **3D low-poly with a fixed ~55° camera instead of 2D sprites:** real ball height for lobs and wall bounces, and far less art to produce.
- **Compatibility renderer:** widest Android support. Lesson from Corniche Rush: the phone rejected shaders that emulators accepted.
- **1920x1080, `canvas_items` / `expand`:** the UI scales to any phone.
- **All numbers in `data/config`:** tuning without touching code.
- **One branch per feature** (`feature/phase1-setup`), merged to `main` after the phone test.
- **Debug keystore committed on purpose:** it is debug only, and release keys are never committed.

Known limit: Godot could not be run in the cloud session (network blocked downloads), so the first real check is the CI build, then the phone test.

#### Next

- The user tests the APK on the phone.
- After OK, merge `feature/phase1-setup` into `main` and start Phase 2 (core match). Propose its plan first.
