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
