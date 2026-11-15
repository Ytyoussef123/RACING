# Player body and animation

Last change: 2026-11-15, motion study line-up poses jog 2.6, sprint 5.6 m/s for the new speeds (branch `feature/player-speed`, commit `cb137a3`). Before that: 2026-11-15, gait blend speeds lowered for the slower players (commit `bea4541`). Before that: 2026-11-15, holding pose: both arms in front for a keeper with the ball in his hands (branch `feature/keeper-ball`, commit `346d461`). Before that: 2026-11-15, walking animation blended with the run (branch `feature/speed-modes`, commit `a89cab9`)

## What it does now
- The player body is a jointed rig built in code (original, no third-party model): hips, spine, neck and head, arms with shoulder and elbow, legs with hip and knee. Shirt with sleeves, shorts, knee-high socks, boots (color picked per player from a palette), hands, gloves for keepers.
- Face with eyes, nose and ears. Hair styles: bald, buzz, short, afro, long, mohawk, as a cap that follows the head shape, tilted back so the hairline is above the forehead and eyes. Skin and hair colors come from the player profile. Players are scaled to their real height.
- Each limb is a few low-poly shapes merged into one mesh and colored per vertex; all players share one material (about ten draw calls per player).
- Procedural animation (`PlayerAnimator`) writes a `RigPose` every frame: running cycle driven by distance covered (longer strides when faster), knees that fold, opposite arms with bent elbows, hips and shoulders twisting, bob, forward lean; lean with acceleration and into turns; idle stance with breathing; keeper ready stance; when the player moves at an angle to where he faces, the hips turn toward the way he goes and the legs step that way so the feet do not slide.
- Walking animation, blended with the run by speed (`walk_gait_full_speed` 1.7 m/s = pure walk, `run_gait_speed` 2.4 m/s = pure run; `move_blend_full_speed` 1.1; the sprint swing still blends by speed / top sprint speed): smaller hip and arm swing, nearly straight elbows, upright body, body highest in mid-step and lowest with both feet down; small walking touches (`touch_walk_thigh_degrees` 24).
- Short actions (`PlayerActions`): kick with follow-through and arms open, tackle, shoulder charge, keeper dive, skill move, goal celebration, and the dribble touch (the foot swings 0.1 s before the ball is in reach).
- Holding pose: while `Player.ball_in_hands` is true the body holds both arms in front, bent, around the ball (`animation.json` -> `hold_arm_forward`, `hold_arm_out`, `hold_elbow`). It follows the ball in the hands (see `ai.md` for the rules).
- The cartoon style was accepted by the user and is kept.

## Where it lives
- Code: `scripts/gameplay/player_rig.gd` (PlayerRig): `build()`, `set_kit()`, `set_look()`, `boot_color_for()`, `refresh()`, `apply(RigPose)`. `scripts/gameplay/rig_mesh_builder.gd` (RigMeshBuilder): `material()`, `merge()`, `cylinder()`, `sphere()`, `dome()`, `capsule()`. `scripts/gameplay/rig_pose.gd` (RigPose): joint channels, `blend()`, `blend_leg()`, `blend_arm()`, `envelope()`. `scripts/gameplay/player_animator.gd` (PlayerAnimator): `update()`, `play()`, `play_touch()`. `scripts/gameplay/player_actions.gd` (PlayerActions): `apply()`. Scene: `scenes/player/player.tscn` (the old capsule body is removed).
- Numbers: `data/config/body.json` -> sizes in meters for `reference_height` 1.75 (`thigh_length`, `shin_length`, `chest_*`, `upper_arm_*`, `head_radius`, ...), `radial_segments` 8, `sphere_rings` 5, `head_segments` 12, `hair_styles` (width, thickness, extra height), `hair_tilt_degrees` -35, `hair_base_drop`, `long_hair_drop`, face keys (`eye_*`, `nose_radius`, `ear_radius`), colors (`default_skin`, `default_hair`, `glove_color`, `boot_colors`, `shorts_darken`, `socks_darken`).
- Numbers: `data/config/animation.json` -> gait (`gait_cycle_*`, `hip_swing_*`, `knee_swing_*`, `arm_swing_*`, `elbow_*`, `run_lean_degrees`, `run_bob`), lean (`accel_lean_*`, `turn_lean_*`), idle (`idle_*`), keeper (`keeper_ready_*`), holding pose (`hold_arm_forward`, `hold_arm_out`, `hold_elbow`), walking (`walk_*`, `walk_gait_full_speed` 1.7, `run_gait_speed` 2.4, `move_blend_full_speed` 1.1), dribble touch (`touch_*`, `touch_walk_thigh_degrees` 24), actions (`kick_*`, `tackle_*`, `shoulder_*`, `dive_*`, `skill_*`, `celebrate_*`), effects (`ball_trail_min_speed`, `ball_visual_scale` 1.5, shake and message pop keys).
- Tests: `tests/motion_study.gd` (run by `tests/screenshot_tour.gd`): frame grids of a jog with the ball and a sprint seen from the side, a turn and a shot from the match camera, a line-up of bodies in poses (idle, keeper ready, jog at 2.6 m/s, sprint at 5.6 m/s, kick, touch, tackle, dive), a close-up of heads, and "MOTION" log lines (ball distance ahead of the player per frame).

## History (newest first)
- 2026-11-15: motion study line-up poses: jog 2.8 -> 2.6 m/s, sprint 5.3 -> 5.6 m/s (`tests/motion_study.gd`), for the user's speeds (run 3.5, sprint 5.8). No change reported to the gait numbers in `animation.json`. Branch `feature/player-speed`, commit `cb137a3`.
- 2026-11-15: gait blend numbers lowered for the slower players (`animation.json`): `move_blend_full_speed` 1.6 -> 1.1, `walk_gait_full_speed` 2.4 -> 1.7, `run_gait_speed` 3.4 -> 2.4; motion study line-up poses: jog 4.0 -> 2.8 m/s, sprint 7.5 -> 5.3 m/s (`tests/motion_study.gd`). Why: the slower runs keep a running stride and the walk stays a walk (player speeds lowered, see `player-movement.md`). Look only; the motion study showed walk, run and sprint strides looking right. Branch `feature/player-speed`, commit `bea4541`.
- 2026-11-15: holding pose with both arms in front when the keeper has the ball in his hands (`Player.ball_in_hands`; `animation.json` -> `hold_arm_forward`, `hold_arm_out`, `hold_elbow`). Why: user request, goalkeeper with the ball. Not yet checked on a screenshot or on the phone (unsure: no motion study frame was reported). Branch `feature/keeper-ball`, commit `346d461`.
- 2026-11-15: walking animation blended with the run by speed, small walking touches. Why: the user's speed modes include a walk. Branch `feature/speed-modes`, commit `a89cab9`.
- 2026-11-14: finer head (12 segments) and hair; turning with the ball keeps it (touch sends the ball to just ahead of where the player will be). Why: the CI motion study showed the head through the hair, and the ball left at the player's side in turns. Branch `feature/player-motion`, commit `edf97d2`.
- 2026-11-14: look fixes from the CI motion study (hair cap tilted back, face added, closer jog touches). Branch `feature/player-motion`, commit `5928680`.
- 2026-11-14: jointed player body, running animation, foot-synced dribble touches; new `body.json`, `animation.json` rewritten. Why: the user compared the game with an eFootball video (movement, 3D quality, ball at the feet). Later he said the cartoon style is fine and should be kept ("we can keep it like this ... cartoon style"). Branch `feature/player-motion`, commit `1983d1f`.
- 2026-11-14: Phase 6: legs, running cycle, kick, tackle lean, keeper dive, skill hop, goal celebration (capsule with legs, procedural). Branch `feature/polish`, commits `cff05f4`, `16fa679`.
- 2026-11-14: Phase 4: head (skin color) and hair (color, style), scaled to real height. Branch `feature/player-stats`, commit `d4786b9`.
- 2026-11-14: Phase 2: orange capsule player with a yellow ring. Branch `main`, commit `19add2a`.

## Do not undo
- Limbs are merged primitive shapes colored per vertex with ONE shared material: about ten draw calls per player. No custom shaders: the phone rejected custom shaders in the other game, and emulators accept things real phones reject.
- The head and hair use a finer mesh (`head_segments` 12). The hair is a cap thicker than the head, tilted back 35 degrees (`hair_tilt_degrees`): with the first coarse 8-segment version the head showed through the hair. The hairline must stay above the eyes.
- Body and animation are look only: no gameplay effect. All sizes stay in `body.json`, all animation numbers in `animation.json`.
- Procedural animation, no rig files: assets stay original and small, every number tunable.
- Cartoon style is kept (the user said so after the video comparison). Do not push toward realism without asking.
- Check the look with the motion study images, not by guessing.

## How to check after a change
- CI green (no script errors, APK built).
- Look at the motion study images and the screenshot tour (`.github/scripts/decode_screenshots.py <log> <folder>`): jog, sprint, turn, shot, pose line-up, heads close-up.
- "MOTION" log lines: ball distance ahead of the player.
- Phone test: body, running and dribbling look.
