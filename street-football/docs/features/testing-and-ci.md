# Tests and CI

Last change: 2026-11-15, new physics tests for shot aim, shot on target and clear (branch `feature/shot-on-target`, commits `436f156`, `acc04df`). Before that: 2026-11-15, AI match test plays 6 matches, motion study adds walk and knock-on grids (branch `feature/speed-modes`, commits `a693967`, `a89cab9`)

## What it does now
- Godot cannot run in the cloud work environment (downloads from github.com are blocked), so CI is the only place the game runs.
- The workflow `.github/workflows/street-football-apk.yml` runs on every push that changes `street-football/` (or the workflow, or the keystore) and on manual start. Steps in order: install Godot 4.7.2 and templates, import, physics tests, stats tests, progression tests, menu flow tests, AI match test, script-error scan, screenshot tour, export debug APK, upload APK, print screenshots.
- Headless suites each must print their "DONE: 0 failure" line: physics (`TESTS DONE`), stats (`STATS TESTS DONE`), progression (`PROGRESSION TESTS DONE`), menus (`UI TESTS DONE`), AI match (`MATCH TESTS DONE`).
- The AI match test plays 6 fixed-seed AI matches (seeds 11, 22, 33, 44, 55, 66) and prints `MATCH RESULT` and `MATCH BALANCE` (goals, shots, saves per match). Latest: 4.67 goals, 30.3 shots, 16.2 saves per 150-second match. It was 3 matches until 2026-11-15; with 3 the goals per match moved from 1.67 to 5.00 between runs.
- New physics tests (2026-11-15): dribbling per mode (walk, sprint, knock-on), turning grip, double pull.
- New physics tests (2026-11-15, shots on target): "shot aim: stick along the goal line still aims inside the goal", "shot aim: aiming at the goal keeps the aim", "shot aim: aiming wide of the goal goes inside the post on that side", "shot aim: no stick aims at the corner away from the keeper", "shot on target: running along the goal line, the shot heads on goal", "clear: long and high, away from our own goal".
- The script-error scan greps all logs for script errors (SCRIPT ERROR, Parse Error, Failed to load script, Invalid call, Invalid access) and prints each distinct error once. Also runs the start scene and the match scene briefly.
- The screenshot tour renders every screen with Xvfb at 2400x1080 and prints each as base64 lines (`SHOT_BEGIN`, `SHOT_DATA`, `SHOT_END`). `.github/scripts/decode_screenshots.py <log> <folder>` turns them back into JPEG images. It never blocks the build.
- Since 2026-11-14 the tour ends with the motion study (`tests/motion_study.gd`; since 2026-11-15 two more grids, `motion_walk_side` and `motion_knockon_side`): frame grids, line-up of bodies, close-up of heads, and "MOTION" log lines (ball distance ahead of the player per frame).
- A final step (`if: always()`) prints the `SHOT_` lines again, because the `SHOT_DATA` lines were filtered out of the earlier log.
- The debug APK is an artifact of every run (`street-football-debug-apk-<sha>`, kept 14 days).

## Where it lives
- CI: `.github/workflows/street-football-apk.yml`; `.github/scripts/decode_screenshots.py`; `.github/keystore/debug.keystore` (debug only, password `android`).
- Tests: `tests/physics_smoke_test.gd` (ball, player, passes, dribbling, shoulder charge, receive assist...), `tests/stats_test.gd` (roster and attributes change play), `tests/progression_test.gd`, `tests/ui_flow_test.gd`, `tests/match_sim_test.gd` (AI vs AI), `tests/screenshot_tour.gd`, `tests/motion_study.gd`. Each has a .tscn (except the study, loaded by the tour).
- Numbers: the match test uses fixed seeds and two fixed crews so balance numbers stay comparable; tests are excluded from the APK (export preset).
- Run in the workflow: `--quit-after 2000` (physics), `3000` (stats, progression, menus), `90000` with `--fixed-fps 60` (AI match).

## History (newest first)
- 2026-11-15: new physics tests (four "shot aim" tests, "shot on target: running along the goal line, the shot heads on goal", "clear: long and high, away from our own goal"); the shot-on-target test found the bug of the ball hitting the kicker's own body. Balance now 4.67 goals, 30.3 shots, 16.2 saves. Branch `feature/shot-on-target`, commits `436f156`, `acc04df`, `2bcb10d`.
- 2026-11-15: the AI match test plays 6 seeded matches instead of 3 (`a693967`); the motion study adds `motion_walk_side` and `motion_knockon_side`; new physics tests for dribbling per mode, turning grip and double pull (`a89cab9`). Why: with 3 matches the goals per match moved from 1.67 to 5.00 between runs, too noisy to judge balance. Branch `feature/speed-modes`.
- 2026-11-14: Screenshot tour renders the match with each camera view; the menu flow test presses the camera chips. Branch `feature/broadcast-camera`, commit `a66b096`.
- 2026-11-14: Motion study added to the tour (frame grids, poses, heads, MOTION lines) after the jointed body; fixes found from its images (hair, face, turn touch). Why: the user cannot see the look, so the look is checked on CI images. Branch `feature/player-motion`, commits `1983d1f`, `5928680`.
- 2026-11-14: Phase 7: progression test suite added to CI (221 checks in total). Stats test counts crew players and free agents separately. Branch `feature/progression`, commits `f78448c`, `6f0f2ac`.
- 2026-11-14: Phase 6: skill move tests, sound and music settings tests. Branch `feature/polish`, commits `cff05f4`, `16fa679`.
- 2026-11-14: Phase 5 CI: render every screen with Xvfb (`2a320a0`), print the screenshot data in a final step (`6b2fa25`), screenshot decoder (`426ce18`), menu flow suite (`88497f3`). Branch `feature/menus`.
- 2026-11-14: Phase 4: match test plays 3 fixed-seed matches with a balance report (`255662b`), match stats for balance (`f613738`), stats suite (`d4786b9`). Branch `feature/player-stats`.
- 2026-11-14: Phase 3 tests: more physics tests for PRESS and pass assist, receive assist, touch dribbling, shoulder charge; AI-vs-AI match test (`02cd4ce`, `6874e1f`, `6055f1d`, `1d96a5e`). Why: catch stuck balls and broken rules before the phone test. Branch `feature/five-v-five`.
- 2026-11-14: CI prints each distinct error once. Two bugs broke the match scene while the physics tests passed (`draw()` clash, `VirtualJoystick` clash), so the match scene is now run and scanned. Branch `main`, commits `2e45e3b`, `bbb81c6`.
- 2026-11-14: Phase 2: headless physics tests and a brief run of the match scene before the APK export. Branch `main`, commit `19add2a`.
- 2026-11-14: Phase 1: workflow that imports the project, runs the scene headless and exports a debug APK; shared debug keystore. Branch `main`, commit `3193378`.

## Do not undo
- CI is the only place the game runs (Godot cannot run in the cloud environment). Never merge on guesses; read the log.
- Physics tests alone are not enough: the match scene must be run and the logs scanned for script errors (they broke the match scene twice while physics tests passed).
- Each distinct error is printed once (easier to read).
- The `SHOT_DATA` lines were once filtered out of the log, so a final step prints them; keep it.
- The tour ends with the motion study; look at it after any change to the body, animation or dribbling.
- The screenshot step never blocks the build (`continue-on-error`).
- The debug APK is an artifact of every run. The debug keystore is committed on purpose (debug only, so builds install over each other); release keys are never committed.
- The AI match test uses fixed seeds and fixed crews; check `MATCH BALANCE` after any gameplay change.
- At the import start Godot logs "Cannot open file strings.en.translation" once. Harmless.

## How to check after a change
- Open the GitHub Actions run: every suite prints its "DONE: 0 failure" line, no script errors, the APK artifact exists.
- Read `MATCH BALANCE`; compare to 4.67 goals, 30.3 shots, 16.2 saves (6 matches).
- Save the job log and run `python3 .github/scripts/decode_screenshots.py <log> <folder>`; look at the images, and the motion study after body or dribbling changes.
- Phone test: install the APK from the artifact (or run the project in the Godot Android editor).
