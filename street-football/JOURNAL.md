# Street Football 5v5: Journal

A dated log, newest entry first: what was done, what was decided and why, and what is next.

## Phases

| # | Phase | Status |
|---|---|---|
| 1 | Setup | Done, tested on phone (2026-11-14) |
| 2 | Core match: court, ball physics, one controllable player, touch controls, shooting | Done, tested on phone (2026-11-14) |
| 3 | 5v5: teams, goalkeepers, formations, basic AI, score, timer | Next |
| 4 | Player stats: data files, attributes affect gameplay, 30 fictional players | Not started |
| 5 | Menus and UI: main menu, team/formation, court selection, results, translations | Not started |
| 6 | Skills and polish: skill moves, animations, sounds, music, effects, wall bounces | Not started |
| 7 | Progression: coins, unlocks, upgrades, save system | Not started |
| 8 | Release build: optimized APK, full file review | Not started |

## Log

### 2026-11-21 — MotionForge: scene uses loaded movements, smart correction between keys

User feedback:
- In Scène, actions must use the movements already loaded in the project, not auto-generated ones.
- After retouching a joint at two keys (for example frames 7 and 12), the frames in between kept the original pose, so the movement was bumpy.

#### Done

- Scène: each action picks one of the loaded movements from a list; nothing is generated any more.
  - New "▶ Jouer" action plays a movement (run, celebration...) without touching the ball, with a facing option and a delay.
  - The receiver's run uses a loaded run movement if there is one.
- Smart correction: the app remembers the original curve of a channel at the first retouch, and the times of the user's keys. Between two consecutive user keys, the frames get a smooth blend of the two retouches on top of the original motion.
  - Automatic after each key (keys up to 2 s apart, checkbox in the Corps tab).
  - A button applies it to the whole movement, the selection or a segment.
  - Saved in the project and kept by undo. Trimming or speed changes reset it.
- Fix: the scene crossfade between two movements no longer blends the hips' ground position and ends before the touch. Passes and controls stay on the ball (foot 14-24 cm from the ball centre in tests, even with a running clip).
- Test: retouching the right arm at frames 2 and 17 of the Running clip.
  - Without correction, frames 8-11 dropped back to 0 degrees.
  - With it, they go smoothly from 34 to 17 degrees.

#### Next

- The user tests on the phone with their own movements.

### 2026-11-21 — MotionForge: Scène mode (several players, passes and receptions)

The user asked for a second mode to set up several players: a player passes, another runs and receives, with control of the ball speed and of how the ball is controlled.

#### Done

All in `street-football/tools/motionforge/motionforge.html`. Also since 2026-11-21 the editor got: Ouvrir reads FBX/GLB/glTF and Android file pickers no longer grey out .fbx; tapping a joint on a phone selects it and ◆ Clé saves on it; the ball can be dragged directly with a finger.

- Mode switch at the top: ✏️ Mouvement / 👥 Scène.
- Scène: copies of the same character, one colour each (J1, J2…), placed by dragging.
- Pass action: movement, target player or a point tapped on the pitch, ball speed (m/s and km/h), height (lob), delay. The kick moment is found automatically.
- Receive action: the receiver turns to the ball and runs so his control touch happens exactly where and when the ball arrives. Control options: stop, left, right, in front, behind, with a distance.
- Passes and receptions can be chained. Warnings when a pass is too slow or a receiver can't arrive in time.
- Timeline lanes per player; whole scene exported as one GLB; scene saved in the project; undo.
- Missing run/pass movements are generated automatically ("Course (auto)", "Passe (auto)").
- Tested headless (desktop and Pixel 7 emulation):
  - J1→J2→J3 chain: the foot is 8–17 cm from the ball centre at every kick and control.
  - Finger drag of players and pass-point picking work.
  - All earlier tests still pass.

#### Next

- The user tests on the phone with their own Mixamo pass / reception / run clips.

### 2026-11-21 — MotionForge: the ball moves with imported movements

Problem reported by the user: after importing a movement, the ball stayed still.

#### Done

- Automatic ball physics in the Ballon tab of `street-football/tools/motionforge/motionforge.html`. Turning the ball on for a movement runs a simulation where the ball reacts to the player's toes, feet, shins, thighs, chest and head (gravity, bounces, rolling friction).
  - Modes: Conduite (each foot touch keeps the ball just ahead of the running player), Libre (pure physics, for kicks and juggling), Auto (picks Conduite if the player travels).
  - Settings: start point, touch strength, bounce, hands (goalkeeper).
- Imported GLB/FBX files that already contain an animated ball (node named ball, ballon, soccer…, for example V5/V6 exports) keep the ball motion. The ball node is removed from the character when such a file is used as the character.
- Duplicate nested bones from re-imported GLBs are hidden.
- Tested headless (desktop and Pixel 7 emulation):
  - On the Mixamo Running clip and a generated 3 s run, the ball stays 0.45 to 1 m in front of the player.
  - A GLB export with ball re-imports with its ball keys.

#### Next

- The user tests on the phone.

### 2026-11-20 — MotionForge Studio animation editor (tool)

#### Done

- The user's MotionForge Studio animation editor (a single HTML file built on Three.js, previously V5) was rebuilt as V6 in `street-football/tools/motionforge/motionforge.html`. It edits player movements with and without the ball, on both phone and PC.
- Main points:
  - Phone layout: 3D view always visible, tabs Mouvements / Corps / Ballon / Vue, tap-to-select joints, Multi selection, camera follows the player.
  - Several movements per project: import more FBX/GLB animations, mirror left/right, trim/cut segments, speed.
  - Smooth key edits on motion-capture clips.
  - Per-movement ball track with "stick to foot/hand" (dribble or carried), a pass/shot/lob generator with bounces and curve, and automatic rolling.
  - The text generator now also does kick, pass and dribble with the ball.
  - Undo/redo, browser autosave, project `.json` to move between phone and PC, GLB export (one animation per movement, optional "Ballon" node) for Godot.
- Tested in headless Chromium at desktop size and with Pixel 7 emulation (tap select, timeline scrub, export, save/reopen, reload restore). Not yet tested by the user on the real phone.

#### Decided

- The folder has a `.gdignore` so Godot ignores it.
- The Mixamo character (`Running.fbx`) is NOT committed (Mixamo license: use in projects, no redistribution of raw files). `build_embedded.py` builds a local copy with the character embedded.

#### Next

- The user tests the tool on the phone.
- Later, the GLB animations feed Phase 6 (animations).

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
