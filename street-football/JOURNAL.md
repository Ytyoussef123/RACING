# Street Football 5v5: Journal

A dated log, newest entry first: what was done, what was decided and why, and what is next.

## Phases

| # | Phase | Status |
|---|---|---|
| 1 | Setup | Done, tested on phone (2026-11-14) |
| 2 | Core match: court, ball physics, one controllable player, touch controls, shooting | Next |
| 3 | 5v5: teams, goalkeepers, formations, basic AI, score, timer | Not started |
| 4 | Player stats: data files, attributes affect gameplay, 30 fictional players | Not started |
| 5 | Menus and UI: main menu, team/formation, court selection, results, translations | Not started |
| 6 | Skills and polish: skill moves, animations, sounds, music, effects, wall bounces | Not started |
| 7 | Progression: coins, unlocks, upgrades, save system | Not started |
| 8 | Release build: optimized APK, full file review | Not started |

## Log

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
