# MotionForge pipeline

Last change: 2026-11-22, one GLB exported by the user's MotionForge Studio app replaces the 18 Mixamo FBX files (branch `feature/motionforge-pack`, commit `bbdf9d4`)

## What it does now
- The player body and all its movements come from one file: `assets/art/players/motionforge/mouvements.glb` (9.6 MB): the Mixamo "Y Bot" character and 18 movements, exported by the user's own app, MotionForge Studio ("Exporter GLB", all movements, with ball).
- MotionForge Studio is a single HTML file (Three.js 0.160.0, French UI, phone and PC). Edit mode: one movement and its ball track (gizmo, smart correction, mirror, retime, ball physics). Scene mode: several players J1, J2... on a 40 x 24 m pitch, actions pass / receive / play, the app places players so the toe meets the ball. It exports GLB (all movements, with a ball node "Ballon") and project files (.json, version 6). The app is not in this repo (its copy embeds the Mixamo character; its own guide says never commit the model).
- Scenes are for checking and correcting movements in the app; the game does not use them.
- The game strips the forward movement (root motion): only the hips' height is taken from a movement, never its way forward.
- The kick moment is read from the ball track: with `"start_at_kick": true` (pass, kick, chip) the movement starts where its "Ballon" first moves faster than `model_kick_speed` 2.0 m/s (minus optional `before_kick`). The `start` value stays as the fallback when a movement has no ball.
- Naming contract (movement name in the app -> game action, `body.json` `model_clips` key):

| Movement in the app | Game action (key) | Start |
|---|---|---|
| sprint | sprint gait | |
| marche | walk | |
| footing | jog | |
| course | run | |
| footing_arriere | jog_backward | |
| passe | pass | at kick |
| tir | kick | at kick |
| pique | chip | at kick |
| degagement_gardien | kick_keeper | 2.07 s |
| reception | receive | 0.3 s |
| tacle | tackle | 0.05 s |
| tacle_course | tackle_run | 0.2 s |
| plongeon | dive | 1.0 s |
| arret_haut | catch | 1.2 s |
| ramassage | scoop | 0.6 s |
| poser_ballon | place | 0.6 s |
| virage_course, changement_direction | in the pack, not used yet | |

- Source Mixamo clips: sprint = Running; marche = Strut Walking; footing = Jog Forward; course = Running 1 with no sprint; footing_arriere = Jog Backward; passe = Soccer Pass; tir = Strike Forward Jog; pique = Chip; degagement_gardien = Goalkeeper Drop Kick; reception = Receive; tacle = Soccer Tackle; tacle_course = Running Slide; plongeon = Goalkeeper Diving Save; arret_haut = Goalkeeper Catch; ramassage = Goalkeeper Scoop; poser_ballon = Goalkeeper Placing Ball; virage_course = Running To Turn; changement_direction = Change Direction.
- Kicks in the pack have a ball added by the app's physics simulation: kick at 0.433 s for passe and tir, 0.500 s for pique.
- The pack also holds an example scene (J1 passes on the ground at 12 m/s to J2 10 m away, who runs with "course" and controls with "reception"; checked: no warnings, kick contact 0.14 m from the ball centre, control 0.28 m).
- How the user updates movements: open `motionforge_football.json` in MotionForge (Ouvrir), correct a movement keeping its name, check it in Scene mode, then "Exporter GLB" (all movements, with ball) and send the file; it replaces `mouvements.glb` as is. Renaming a movement breaks its link to the game action; a new movement needs a new entry in `model_clips`. `motionforge_football.json` was given to the user and is not in the repo.

## Where it lives
- Data: `assets/art/players/motionforge/mouvements.glb`.
- Code: `scripts/gameplay/model_library.gd` (ModelLibrary): `load_scene`, `animation_named` (all movements of a GLB are read once), `kick_time`, short bone names (including "mixamorigHips" without separator), `find`. Older single-file FBX "file" entries in `model_clips` still work. `scripts/gameplay/model_body.gd` (ModelBody, 408 -> 310 lines after the split): removes the exported "Ballon" node from each player; skips the second copy of each bone (three.js exports one bone set per skinned mesh, the second nested in the first with no offset: `ModelBody._is_alias`) so only the animated set is posed.
- Numbers: `data/config/body.json` -> `model_scene` (`res://assets/art/players/motionforge/mouvements.glb`), `model_clips` (per action: "anim" = the movement's name, "start", "start_at_kick", "before_kick" (optional, not used yet), "wind", "rate", "out"), `model_kick_speed` 2.0, `model_gaits`.
- Tests: the 10 CI suites and the screenshot tour / motion study (see `testing-and-ci.md`).

## History (newest first)
- 2026-11-22: one GLB from the user's MotionForge Studio app replaces the 18 FBX files. The starting pack was built with the app itself, driven headless (Playwright): 18 clips imported and named, ball added to the three kicks by the app's physics, example scene, exported with "Exporter GLB". Game: `body.json` `model_scene` = the GLB, `model_clips` use "anim" instead of "file", "start_at_kick" and `model_kick_speed`; new `ModelLibrary`; `ModelBody` removes the "Ballon" node and skips duplicate bones. Why: the user built their own animation app and asked for points 1-5 (one GLB, a naming contract, kick moment from the ball track, scenes only for checking, root motion stripped). CI run 44964595165 green, all 10 suites 0 failures, balance unchanged (2.33 / 12.0 / 7.8). APK 48.5 -> 31.4 MB. Phone test pending. Branch `feature/motionforge-pack`, commit `bbdf9d4`.

## Do not undo
- One GLB, movements found by name: keep the names of the contract above when correcting movements in the app. Renaming one breaks its link to the game action.
- The game takes only the hips' height from a movement, never its way forward (point 5).
- Scenes of the app are not used by the game (point 4).
- It is still the Mixamo character: keep the repo private, never commit the app itself (its copy embeds the model). The raw FBX files were removed but stay in the git history.

## How to check after a change
- CI green (all 10 suites 0 failures, balance 2.33 / 12.0 / 7.8 unless gameplay changed).
- Motion study and screenshot tour: the movements play (jog, run, sprint, pass, kick, tackle, dive).
- A new GLB: every "anim" name in `body.json` `model_clips` exists in it; kicks have a ball ("Ballon") so "start_at_kick" works.
- Phone test: frame rate and the movements.
