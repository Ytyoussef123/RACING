# Camera

Last change: 2026-11-14, three views Close / Normal / Wide, lower default, Camera row in Settings (branch `feature/broadcast-camera`, commits `a66b096`, `6a68f74`)

## What it does now
- The match camera sits above the near long side and follows the ball smoothly (look-ahead along the ball's velocity, limited at the court ends). It shakes briefly on goals and post hits.
- Three views (`data/config/camera.json` -> `presets`):
  - close: 38 degrees pitch, 13.5 m, fov 45, z follow 0.6
  - normal (default): 44 degrees, 17 m, fov 45, z follow 0.5
  - wide: 55 degrees, 19 m, fov 45, z follow 0.4 (the original Phase 2 view)
- The view is chosen in Settings (Camera row, English and French) and saved in `user://settings.cfg` (`display/camera`).
- Shake strength and duration come from `animation.json` (look only).

## Where it lives
- Code: `scripts/gameplay/match_camera.gd` (MatchCamera): `apply_preset()`, `preset()` (unknown name gives the default), `snap_to()`, `follow()`, `shake()`. `scripts/core/settings.gd` (Settings autoload): `camera_view`, `set_camera_view()`, save and load. The Camera row is in `scripts/ui/settings_screen.gd` (constant `CAMERA_VIEWS`, chips named `Camera_close`, `Camera_normal`, `Camera_wide`).
- Numbers: `data/config/camera.json` -> `presets`, `default_preset` "normal", `follow_speed` 4.0, `look_ahead_seconds` 0.25, `x_limit_margin` 6.0. `data/config/animation.json` -> `goal_shake_*`, `hit_shake_*`.
- Tests: `tests/screenshot_tour.gd` renders the match with each view (`match_camera_close`, `match_camera_normal`, `match_camera_wide`); `tests/ui_flow_test.gd` presses the camera chips (`Camera_close`, `Camera_normal`) and checks `Settings.camera_view` ("settings: close camera").

## History (newest first)
- 2026-11-14: three views Close / Normal / Wide, default lowered to Normal, `MatchCamera.apply_preset()`, Camera row in Settings, screenshot tour and menu test updated. Why: in the reference video (eFootball, the game the user showed) the camera is lower and closer, so the bodies and running are seen from the side; our steep Phase 2 view (55 degrees, 19 m) hid the new bodies. Balance unchanged (look only): 5.00 goals, 28.3 shots, 11.0 saves. Branch `feature/broadcast-camera`, commits `a66b096` (code), `6a68f74` (docs).
- 2026-11-14: camera shake on goals and post hits. Branch `feature/polish`, commit `cff05f4`.
- 2026-11-14: first camera: fixed angle 55 degrees, following the ball. Branch `main` (`feature/core-match`), commit `19add2a`.

## Do not undo
- Keep `wide` as the original Phase 2 view (55 degrees, 19 m) so the old look stays available.
- The default is Normal (44 degrees, 17 m), decided 2026-11-14 because the reference video's camera is lower and closer and the steep old view hid the new bodies. It can be changed in `camera.json` -> `default_preset`; the user picks the view he likes on the phone.
- The near-side fence is not drawn (it would hide the play); the physics walls are still there.
- The camera is look only: it must not change balance.

## How to check after a change
- CI green; screenshots `match_camera_close`, `match_camera_normal`, `match_camera_wide` and the settings screen (the Camera row must fit), decoded with `.github/scripts/decode_screenshots.py`.
- `tests/ui_flow_test.tscn` passes (camera chips).
- `MATCH BALANCE` unchanged (camera is look only).
- Phone test: pick each view in Settings and play.
