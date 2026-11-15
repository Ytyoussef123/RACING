# Street Football 5v5: Journal

A dated log, newest entry first: what was done, what was decided and why, and what is next.

## Phases

| # | Phase | Status |
|---|---|---|
| 1 | Setup | Done, tested on phone (2026-11-14) |
| 2 | Core match: court, ball physics, one controllable player, touch controls, shooting | Done, tested on phone (2026-11-14) |
| 3 | 5v5: teams, goalkeepers, formations, basic AI, score, timer | Done, waiting for phone test |
| 4 | Player stats: data files, attributes affect gameplay, 30 fictional players | Done, waiting for phone test |
| 5 | Menus and UI: main menu, team/formation, court selection, results, translations | Done, waiting for phone test |
| 6 | Skills and polish: skill moves, animations, sounds, music, effects, wall bounces | Done, waiting for phone test |
| 7 | Progression: coins, unlocks, upgrades, save system | Done, waiting for phone test |
| 8 | Release build: optimized APK, full file review | Not started |

The player-motion work is an extra feature branch between Phase 7 and Phase 8 (`feature/player-motion`, created from `feature/progression`), waiting for the phone test. `feature/broadcast-camera` (created from `feature/player-motion`) adds camera views and also waits for the phone test. `feature/speed-modes` (created from `feature/broadcast-camera`) adds walk, run, sprint and knock-on, and waits for the phone test. `feature/shot-on-target` (created from `feature/speed-modes`) adds shots on target and CLEAR, and waits for the phone test.

## Log

### 2026-11-15 — Shots on target and CLEAR

#### Why

- The user asked that an attacker who is not lined up with the goal still shoots on target ("tir cadré"). Shots can still miss, but not just because he is not facing the goal.
- He named a "Blitz" shot (a curling power shot from the reference game) for later: NOT done, planned.
- He agreed to CLEAR in our own half (SHOOT becomes CLEAR), from the list of the video's HUD items.

#### Done

- Shot aim: `scripts/gameplay/shot_aim.gd` (`ShotAim.target`). Every shot is aimed at a point on the opponent's goal line. A stick pointing at or near the goal keeps its aim (it can still miss up to `shot_assist_margin` 1.5 m past a post); a stick pointing elsewhere aims `shot_post_inset` 0.45 m inside the post on that side; no stick aims at the corner away from the keeper. The point is computed when SHOOT is released (a queued shot keeps it); the shot goes from the ball to it. The AI's aim already crosses the goal, so its shots are aimed as before.
- Error still decides if it is on target: finishing, long shots, weak foot, speed mode, first-time skill, plus a tight angle (goal seen under `shot_tight_angle_degrees` 20 degrees: error up to x`shot_tight_error_mult` 1.6) and the back to the goal (more than 90 degrees from the facing: up to x`shot_turn_error_mult` 1.5).
- `scripts/gameplay/kick_accuracy.gd` (`KickAccuracy`): `with_error`, `weak_foot_mult`, `pace_mult` (moved out of `BallHandling` to keep it under ~300 lines) and the new `shot_angle_mult`.
- CLEAR: with the ball in our own half (`clear_zone_frac` 0.5 of the court, from our goal) the SHOOT button is labelled CLEAR (`BTN_CLEAR`, "CLEAR" / "DÉGAGER"); a tap kicks the ball long and high where the stick points, never back toward our goal. A SHOOT held for a clearance must be lifted before it can start a shot. `HumanInput.read(attacking, clearing)`, `TouchControls.set_defense_layout(defense, clearing)` with `CLEAR_LABELS`, `PlayerIntent.clear_pressed`, `BallHandling._clear`.
- Bug found by the new shot test and fixed: a shot or pass played back across the kicker's own body hit his own collision circle and bounced away. After any kick the kicker's body now lets the ball through for `kick_pass_through_seconds` 0.15 s (`player.ghost_timer`, like a nutmegged player).
- Keeper save chance raised (see Numbers).
- Tests: "shot aim: stick along the goal line still aims inside the goal", "shot aim: aiming at the goal keeps the aim", "shot aim: aiming wide of the goal goes inside the post on that side", "shot aim: no stick aims at the corner away from the keeper", "shot on target: running along the goal line, the shot heads on goal", "clear: long and high, away from our own goal".
- Branch `feature/shot-on-target`, commits `436f156` (shots on target, CLEAR, `KickAccuracy`), `acc04df` (kicked ball passes through the kicker), `2bcb10d` (keeper save chance +0.05).

#### Numbers

- `data/config/player.json`: `shot_post_inset` 0.45, `shot_assist_margin` 1.5, `shot_tight_angle_degrees` 20, `shot_tight_error_mult` 1.6, `shot_turn_error_mult` 1.5, `kick_pass_through_seconds` 0.15, `clear_speed` 17, `clear_lift` 6.5, `clear_error_mult` 1.5 (on the through-pass error), `clear_zone_frac` 0.5.
- `data/config/ai.json`: `keeper_save_chance` easy / normal / hard 0.4 / 0.6 / 0.75 (was 0.35 / 0.55 / 0.7).

#### Checked

- Balance over 6 AI matches: after the shot change and the pass-through fix 5.17 goals, 31.0 shots, 15.0 saves per match; after the keeper change 4.67 goals, 30.3 shots, 16.2 saves per match (3 to 7 goals per match).

#### Next

- Phone test of shots from odd angles and of CLEAR.
- The goalkeeper with the ball (hands / feet), then team movement (creating space), as agreed with the user.
- Planned, not done: the "Blitz" curling shot.

### 2026-11-15 — Speed modes: walk, run, sprint, knock-on

#### Why

- The user designed four speeds with the ball, after answering my questions:
  - Joystick pushed softly = walk, the ball very close. Pushed fully = run ("first speed", as before). SPRINT = sprint ("third speed"), the ball about 0.5 m ahead. Joystick pulled hard twice = knock-on: the ball pushed an exact distance (he chose 1 to 1.5 m), the player runs onto it and pushes again.
  - Without the ball: walk / run / sprint, no knock-on.
  - Three fixed steps with a visual cue on the joystick ring. Knock-on always at full speed. It lasts while the stick stays pushed hard and ends when the stick is softened or released, or on a pass / shot / loss of the ball. A ball pushed ahead can be stolen.
  - The gesture: the thumb stays on the screen, edge, back a little, edge again quickly. The single knock-on is removed from the forward flick.
  - On defense: PRESS with the joystick moved = sprint where it points; PRESS alone = automatic press.
  - Walking animation. Turning sharper when slow and wider at full sprint. Accuracy a little better walking and worse sprinting. Walking recovers stamina faster. Stats as before.
  - The AI will use these modes later, after he tests the controls (agreed).
- He also asked to always use Sonnet (agents `code-reader`, `docs-writer`) to read code and history, and Opus at max effort only to modify code (already in `CLAUDE.md`).

#### Done

- Movement: `PlayerIntent.walk` and `PlayerIntent.knock_on`; `PlayerMotion.step(delta, move, sprint, dribbling, walk, knock_on)` with a fixed walking speed, knock-on at full sprint speed without the dribbling slowdown, run unchanged. Turning grip by speed (`turn_grip_walk`, `turn_grip_sprint`): sharper turns when slow, wider at full sprint (the "heavier movement" idea left open before, now done by his choice). Walking or standing recovers stamina faster; the knock-on drains like a sprint.
- Dribbling: four modes (`Dribbling.Mode`: WALK, RUN, SPRINT, KNOCK_ON). Sprint now keeps the ball close. Walk, sprint and knock-on touches aim at a gap (`Dribbling._push_for_gap`, replaces `_knock_on_push`): the push is computed so the ball's farthest point is the gap ahead of the player (walk 0.45 m, sprint 0.55 m, both times the dribbling stat; knock-on exactly 1.3 m). Run unchanged.
- Controls: walk below `walk_threshold` 0.6 of the stick, yellow ring in the run zone, orange in knock-on mode; double pull detection in `FloatingStick`; keyboard Ctrl = walk, K = knock-on. Defense: PRESS with the stick moved = sprint where it points (`scripts/gameplay/human_assists.gd`, moved out of `match.gd`).
- Skill moves: the forward flick no longer makes a knock-on; with nobody in the way it is no move and the skill cooldown is given back.
- Animation: walking gait blended with the run by speed, small walking touches.
- Accuracy by speed mode for everyone (passes and shots): x0.85 walking, x1.15 sprinting, x1.2 in a knock-on.
- AI: `shoot_range` lowered to 8 / 9.5 / 11 m (easy / normal / hard) because the close sprint made the AI shoot from too far. The AI does not walk or knock-on yet.
- Tests: the AI match test plays 6 seeded matches instead of 3; new physics tests (dribbling per mode, turning grip, double pull); the motion study adds `motion_walk_side` and `motion_knockon_side`.
- Branch `feature/speed-modes`, commits `a89cab9` (speed modes), `a693967` (balance test with 6 matches), `9949e3f` (tuning: walk reach 0.55, sprint reach 0.62, AI `shoot_range`, test limits), `86ed455` (walking push 0.8 m/s), `45a870f` (walk and sprint touches aim at a gap, and these docs).

#### Numbers

- `data/config/player.json`: `walk_speed` 2.2, `turn_grip_walk` 1.3, `turn_grip_sprint` 0.6, `knock_on_speed_factor` 1.0, `knock_on_distance` 1.3, `knock_on_reach` 0.6, `dribble_max_push` 6.0 (was `knock_on_max_push`), `dribble_walk_reach` 0.55, `dribble_walk_gap` 0.45, `dribble_sprint_reach` 0.62, `dribble_sprint_gap` 0.55 (removed: `dribble_walk_extra`, `dribble_touch_extra_sprint`), `pace_error_mult_walk` 0.85, `pace_error_mult_sprint` 1.15, `pace_error_mult_knock_on` 1.2.
- `data/config/controls.json`: `walk_threshold` 0.6, `double_pull_out_fraction` 0.9, `double_pull_in_fraction` 0.6, `double_pull_seconds` 0.5, `double_pull_max_degrees` 45, `stick_run_color`, `stick_knock_on_color`.
- `data/config/stat_effects.json`: `walk_recover_mult` 1.6. `data/config/ai.json`: `shoot_range` 8 / 9.5 / 11.

#### Checked

- CI green.
- Ball distance ahead of the player (motion study, centre to centre): walk 0.33 to 0.44 m (steady), run 0.54 to 0.98 m, sprint settling at 0.41 to 0.62 m within 0.6 s, knock-on 0.55 to 1.41 m.
- Balance over 6 matches: with the old `shoot_range` 2.33 goals, 29.3 shots, 13.3 saves (8 % of shots scored instead of 18 %); after lowering it 3.67 goals, 33.2 shots, 14.0 saves; final, after the gap touches: 3.17 goals, 28.2 shots, 12.2 saves per 150-second match.
- Lesson: a fixed push cannot hold the gap for every player (the dribbling stat scales it, and touches come every 0.3 s), so with 0.6 then 0.8 m/s the walking ball drifted into the feet (0.13 to 0.15 m); aiming each touch at a gap keeps it exact.

#### Next

- Phone test of the four modes and the double pull.
- Then the AI using walk and knock-on.
- Then the HUD items from the video (see `docs/features/touch-controls-and-hud.md`).

### 2026-11-14 — Feature files (docs/features/)

#### Why

- The user asked that every change to every feature be saved in a file, so that before changing a feature the last changes are found quickly and nothing is rebuilt or broken.

#### Done

- `docs/features/` with one file per feature (17 files, index and template in `docs/features/README.md`): what it does now, where it lives (code, numbers, tests), history newest first (date, what, why, branch, commit), "Do not undo" (decisions and lessons), how to check after a change.
- Written from this journal and the git history; open points checked against the code and git.
- New rule 11 in `CLAUDE.md`: read the feature's file before changing it, add the change to its history after.
- The `docs-writer` agent now also owns these files.
- Branch `feature/broadcast-camera`.

### 2026-11-14 — Camera views: Close, Normal, Wide

#### Why

- In the reference video the camera is lower and closer than ours, so the players' bodies and running are seen from the side. Our Phase 2 camera looked steeply down (55 degrees, 19 m), which hides the new bodies.

#### Done

- Three views in `data/config/camera.json` -> `presets` (pitch, distance, field of view, how much the camera follows the ball across the court): Close (38 degrees, 13.5 m), Normal, the new default (44 degrees, 17 m), Wide = the original view (55 degrees, 19 m).
- New Camera row in Settings (English/French), saved on the phone with the other settings.
- `MatchCamera.apply_preset()`; the screenshot tour renders the match with each view; the menu flow test presses the camera chips.

#### Checked

- CI green (all tests, no script errors, APK built). Screenshots of the three views and of the settings screen reviewed (the new row fits).
- Balance unchanged (the camera is look only): 5.00 goals, 28.3 shots, 11.0 saves.

#### Next

- The user picks the view he likes on the phone; the default can be changed in `camera.json` -> `default_preset`.

### 2026-11-14 — Player motion: body, running animation, ball at the feet

#### Why

- The user compared the game with an eFootball video and pointed out three things that were missing: how the players move, the 3D quality of the players, and how the ball reacts at the player's feet while he runs.

#### Done

- New jointed body built in code, original (no third-party model): hips, spine, neck and head, arms with shoulder and elbow, legs with hip and knee. Shirt with sleeves, shorts, knee-high socks, boots (color picked per player from a palette), hands, gloves for keepers. Face with eyes, nose and ears; hair styles (bald, buzz, short, afro, long, mohawk) as a cap that follows the head shape, tilted back so the hairline is above the forehead. Each limb is a few low-poly shapes merged into one mesh and colored per vertex, so all players share one material (about ten draw calls per player). Files: `scripts/gameplay/player_rig.gd` (PlayerRig), `scripts/gameplay/rig_mesh_builder.gd` (RigMeshBuilder), sizes in the new `data/config/body.json`. The old capsule body is removed from `scenes/player/player.tscn`.
- New procedural animation: `scripts/gameplay/player_animator.gd` (PlayerAnimator) writes a `RigPose` (`scripts/gameplay/rig_pose.gd`) every frame: running cycle driven by the distance covered (longer strides when faster), knees that fold during the swing, opposite arms with bent elbows, hips and shoulders twisting, bob, forward lean; lean with acceleration and into turns; idle stance with breathing; keeper ready stance; when the player moves at an angle to where he faces, the hips turn toward the way he goes and the legs step that way so the feet don't slide. Short actions (kick with follow-through and arms open, tackle, shoulder charge, keeper dive, skill move, goal celebration) in `scripts/gameplay/player_actions.gd` (PlayerActions). Numbers in `data/config/animation.json`.
- Ball at the feet (`scripts/gameplay/dribbling.gd`, `scripts/gameplay/dribble_assist.gd`):
  - Every dribble touch is now done by a foot. Running onto the ball, the foot starts its swing 0.1 s before the ball is in reach, so it meets the ball exactly when the touch lands. The foot on the ball's side is used, otherwise the preferred foot.
  - Jog dribbling is closer: the ball stays about 0.3 to 1.0 m ahead with a touch about every 0.3 s; sprinting still knocks it 1.5 to 3 m ahead.
  - Turning with the ball: the touch sends the ball to just ahead of where the player will be once turned. If the ball is out of reach when the stick turns, the player first goes to it, then turns with it (new `PlayerIntent.dribble_dir`).
  - After a long sprint knock-on, the ball stays his while he chases it (sprint leash until his next touch), even if he lets go of SPRINT or starts a shot.
  - The ball is held a little closer at the feet when standing. The ball's rolling now matches its drawn size.
- Look is checked on CI: the screenshot tour ends with a motion study (`tests/motion_study.gd`): frame grids of a jog with the ball and a sprint seen from the side, a turn and a shot seen from the match camera, a line-up of bodies in poses (idle, keeper ready, jog, sprint, kick, touch, tackle, dive) and a close-up of heads. It also prints the ball's distance ahead of the player for every frame ("MOTION" lines in the log).

#### Numbers

- New `data/config/body.json` (all body sizes, hair styles, colors).
- `data/config/animation.json` rewritten for the jointed body (gait, lean, idle, actions; effects numbers unchanged).
- `data/config/player.json`: `dribble_touch_extra_min` 1.6 -> 1.2, `dribble_touch_extra_run` 2.6 -> 1.7, `dribble_distance` 0.55 -> 0.48; new `dribble_touch_windup` 0.1, `dribble_windup_reach_margin` 1.3, `dribble_foot_side_offset` 0.12, `dribble_turn_reach` 0.85, `dribble_turn_assist_degrees` 50, `dribble_turn_touch_time` 0.3, `dribble_turn_touch_lead` 0.6, `dribble_turn_touch_max_speed` 9.0.

#### Checked

- CI: all headless test suites pass (physics, stats, progression, menus, AI match), no script errors, APK built. The motion study images were reviewed after each change; they led to fixing the hair (the head showed through), adding a face, closer jog touches, and the turn touch (the ball was left at the player's side in turns).
- Balance (3 fixed-seed AI matches, final run): 5.00 goals, 28.3 shots, 11.0 saves per 150-second match (before this work: 3.33 goals, 24.3 shots, 9.0 saves). Players now keep the ball when they turn, so attacks last longer and there are more shots. With only 3 matches the goal count moves a lot between runs (1.67 to 5.00 during this work); to be checked on the phone: if scoring feels too easy, the keeper save chances in data/config/ai.json can be raised.

#### Next

- Phone test of the new bodies, running and dribbling.
- Possible next steps proposed to the user: a lower, wider match camera with a Close / Normal / Wide setting (shows the bodies better, as in the reference video); the HUD items seen in the video (mini-map, name tags, next-player marker, CLEAR in our own half); optionally more weight in the movement (slower turns at full speed), which changes how the controls feel and is left for the user to decide.

### 2026-11-14 — Phase 7: progression

#### Done

- Branch `feature/progression`, created from `feature/polish` (Phase 6) → `feature/menus` (5) → `feature/player-stats` (4) → `feature/five-v-five` (3). Phases 3-7 all wait for the phone test; nothing is merged into `main` yet. Version 0.7.0 (version code 7).
- Save (`SaveGame` autoload, `scripts/core/save_game.gd`): `user://savegame.json`, versioned (`save_version` 1). Holds coins, signed players and their levels, My Crew (5 starters, the rest on the bench, formation), unlocked courts and the match record (played, wins, draws, losses, goals). Writes go through a temporary file. A damaged save is kept as `savegame.bad.json` and a new save starts.
- My Crew: 7 new fictional rookies (free agents, overall 65-75, weaker than the crews, which average about 80). Starters: keeper Bruno Sallestra, Ilyes Benzerrak, Arjun Malhovar, Leon Achterbosch, Moussa Kanderé. Bench: Tomás Velarrubia, Rayan Ouaddi. In Quick match My Crew is the default home side; the 6 street crews stay available as exhibition teams and as opponents. `my_crew` is a team built in code by `SaveGame` (orange kit, short name YOU) and can never be an opponent.
- Squad builder (MY CREW screen): starters and bench lists; tap two players to swap; INFO opens the player card; the LV button upgrades with coins; a warning shows if no keeper starts. Coins and the match record are shown.
- Coins after every match (`data/config/progression.json`): win 150, draw 80, loss 50, plus 15 per goal scored, times 0.8 Easy, 1.0 Normal, 1.4 Hard. Results screen shows "+N coins (total M)". Starting coins 500. Coins shown on the main menu.
- Shop (new SHOP button): 10 fictional free agents (overall 74-89, e.g. Bayo Ruiz-Okun, Kaito Shimazu, Diego Fuenmayorte) priced 400 + 60 per overall point above 70 (640 to 1540). Two new courts to unlock: Rooftop Cage (32 x 20 m, walls, neon colors; 600 coins) and Beach Court (34 x 20 m, no walls, sand; 900 coins). Locked courts are greyed with their price on the court screen. Signed players join the bench.
- Upgrades: levels 1-5, costs 250, 450, 700, 1000; +2 to every attribute per level, applied through the stat sheet, so gameplay really changes.
- Court surfaces: courts have `ball_friction_mult` and `ball_bounce_mult` (sand 1.9 / 0.7, rooftop 0.9 / 1.05). The ball prediction copy keeps the surface.
- Free agents are players in no crew (`Roster.free_agent_ids`). Total roster: 47 fictional players (30 in crews + 17 free agents). Documented in `docs/player-data.md`.

#### Decisions (and why)

- **Crew players are never sold:** you never meet your own players in the other team.
- **My Crew starts weaker than the street crews (65-75 vs about 80):** gives a reason to earn coins, sign players and upgrade.
- **Upgrades add to attributes through the stat sheet:** levels change real gameplay with no special-case code.
- **Writes through a temporary file, damaged save kept as `savegame.bad.json`:** a crash or bad file never destroys progress silently.
- **`my_crew` built in code from the save, never an opponent:** it changes as you sign and upgrade players, and you never play against yourself. The AI match test uses two fixed crews instead, so the balance numbers stay comparable.
- **Sand slows the ball and rooftop is slightly faster:** courts feel different, and the numbers sit in court data.

#### Checked

- New progression suite (`tests/progression_test.tscn`) in CI: new save, rewards (3-1 win on Normal = 195), shop (too expensive, buying, no double buy, crew players not for sale, price grows with overall), upgrades (cost, attribute +2, max level, reset on new save), squad swaps, court unlock, save and load round trip with level bonuses, damaged save, sand surface (ball rolls about half as far), My Crew team (5 starters, keeper wears 1, never an opponent).
- Menu tests: shop button, squad swap and upgrade, buying a player and a court.
- 221 test checks pass in total.
- AI balance unchanged: 3.33 goals per 150 s (the AI match test uses two fixed crews, not My Crew).
- CI screenshots reviewed: main menu with coins and SHOP, My Crew screen, shop, locked courts.
- Not yet tested on the phone.

#### Next

- The user's phone tests of Phases 3-7 and their remarks.
- Then merges into `main`.
- Then Phase 8: release build. It needs a release keystore from the user, kept as a GitHub secret. A full read-through of all released files comes before release, then an optimized APK.

### 2026-11-14 — Phase 6: skills and polish

#### Done

- Branch `feature/polish`, created from `feature/menus` (Phase 5) → `feature/player-stats` (4) → `feature/five-v-five` (3). Phases 3-6 all wait for the phone test; nothing is merged into `main` yet. The user asked to keep working while they cannot test.
- Animation (procedural, no rig; `data/config/animation.json`, `scripts/gameplay/player_animator.gd`): players now have legs; running cycle with leg swing, bob and forward lean; kick with the preferred foot; tackle lean; shoulder lean; keeper dive toward the ball on saves; skill-move hop; goal celebration jumps by the scorer.
- Effects (`scripts/gameplay/effects.gd`): ball trail on fast balls, dust puffs on won tackles and shoulder duels, confetti in the scorer's colors at the goal, camera shake on goals and post hits, GOAL! text pops. The ball is drawn 1.5x bigger than its physics size so it reads on a phone (look only).
- Match events channel (`MatchContext.emit_event`): kicks, tackles, saves, skills and ball hits (ground, wall, post, net) feed sounds and effects.
- Sound (`Sfx` autoload, `data/config/audio.json`): original sounds and a 21-second 90 BPM street beat (A minor) generated by `tools/generate_audio.py` (Python + numpy, sine waves and noise, no samples): soft and hard kicks, ground bounce, cage wall rattle, post ping, net swish, short and full-time whistles, goal horn, tackle scuff, keeper save, UI click. Volume follows the impact strength. Music plays in the menus (`music_in_match` false). New Settings rows: Sound on/off, Music on/off (saved).
- Skill moves (`scripts/gameplay/skill_moves.gd`, `data/config/skills.json`): flick the joystick with the ball (quick swipe and release, under 0.22 s; keyboard C). Direction compared to where the player faces picks the move: forward = knock-on, rainbow flick over a defender within 3 m, nutmeg through a defender within 1.6 m (the ball passes through him); side = elastico or step-over; back = heel-flick pass to a teammate behind, roulette or drag-back. Minimum skill-move stars per move. Success chance = 0.45 + 0.1 per star + dribbling bonus (max 0.97); a miss is a bad touch (ball lost). A good move can freeze defenders within 2.6 m (chance grows with stars). After a move the ball is played to the player himself, so the receive assist runs him onto it. The move name pops up above the player (e.g. "Elastico!", "Lost it!").
- Special skills now in play: flip_flap, rainbow, nutmeg, roulette, heel_flick unlock moves; first_time_shot makes one-touch shots more accurate (error x0.6); rabona removes the weak-foot penalty.
- The AI uses skill moves when a defender is within 2 m (skill_tendency easy 0.05 / normal 0.15 / hard 0.3 per decision, scaled by the player's stars).
- Wall bounces were already done in Phase 2 (cage court).

#### Decisions (and why)

- **Procedural animation, no rig:** keeps assets original and files small, and every number stays tunable in `animation.json`.
- **Sounds generated by a script, no samples:** original work with no license issue; the generator is in the repo and listed in the README licenses table.
- **Match events channel:** one place (`MatchContext.emit_event`) feeds sounds and effects, so gameplay code does not call them directly.
- **Ball drawn 1.5x bigger than its physics size:** reads better on a phone; physics unchanged.
- **Failed skill move loses the ball:** gives risk against reward, with stars and dribbling raising the odds.
- **Music off in the match by default:** it plays in the menus only (`music_in_match` false).
- **Skill moves on a joystick flick:** a proposal (no extra button, direction picks the move); it waits for the user's opinion, since controls follow eFootball habits.

#### Checked

- 6 new skill tests (knock-on, elastico, nutmeg, rainbow, drag-back, failed move) and sound/music settings in the menu test; all suites green.
- Balance with skills: 3.33 goals, 24.3 shots, 9.0 saves per 150 s AI match (results 1-2, 1-1, 2-3).
- CI screenshots reviewed: legs, bigger ball, new settings rows.
- Not yet tested on the phone.

#### Next

- Phase 7 (progression: coins, unlocks, upgrades, save system, squad builder) while waiting for the phone tests.
- Then the user's remarks, merges into `main`, and Phase 8 release build.

### 2026-11-14 — Phase 5: menus and UI

#### Done

- Branch `feature/menus`, created from `feature/player-stats` (Phase 4), which comes from `feature/five-v-five` (Phase 3). The user asked to keep working while they cannot test; Phases 3, 4 and 5 all wait for the phone test. Nothing is merged into `main` yet.
- Main menu (`scenes/menus/main_menu.tscn`, now the start scene; the old Phase 1-4 start screen is removed): QUICK MATCH, MY CREW, SETTINGS, a big tilted "5v5" tag, version and device info. Android back button (`quit_on_go_back` disabled): quits on the main menu, goes back on other screens, pauses/resumes in the match.
- Quick match flow: (1) choose the crews, yours and the opponent with < and >, shown as team cards (kit colors, team rating = average overall, 5 players with number, name, position, overall); tap a player to open his card. (2) Formation: 5 formation chips and a mini court with your crew placed by `SlotAssigner`. (3) Court and rules: Concrete Cage (walls) or Open Lot (no walls) with size, difficulty Easy/Normal/Hard, match length 3/4/5 minutes, then PLAY.
- Results screen: YOU WIN / DRAW / YOU LOSE, score with crew names and colors, goals (time, crew, scorer, own goal marked), match stats (shots, saves, passes completed, balls won, possession %), REMATCH and MAIN MENU. Goal scorers and times are now recorded in the match.
- My crew screen and player card overlay: name, overall, nationality, age, height, foot, positions, playstyle, weak foot x/4, skill moves x/5, special skills, and the 25 attributes in 6 groups as colored bars (cyan 85+, green 75+, yellow 60+, red below).
- Settings (saved in `user://settings.cfg`): language English/Français, show FPS (counter on every screen), touch button size small/normal/large.
- In-match pause: PAUSE button top-left (replaces MENU) opens RESUME, FORMATION, QUIT MATCH.
- Street-style theme from `data/config/ui.json` (`UiTheme` autoload): dark buttons with an orange tape stripe, orange main action buttons, cyan selection chips, rounded cards, drawn asphalt background with diagonal tape stripes.
- Code: autoloads `UiTheme`, `Screens` (navigation by screen id, scene paths in `ui.json`) and `Settings`; `MenuScreen` base class and `UiBuild` helpers build layouts in code on a minimal .tscn per screen; components `TeamCard`, `PlayerCard`, `FormationPreview`, `StatBar`, `PauseMenu`.
- About 90 new texts in English and French (menus, results, card, 25 attribute names, French positions G/DÉF/MIL/AIL/ATT) in `locale/strings.csv`.
- New review tool: CI renders every screen with a virtual display (Xvfb + Mesa OpenGL) at 2400x1080 (a 20:9 phone) via `tests/screenshot_tour.gd` and prints them in the log; `.github/scripts/decode_screenshots.py` turns them back into images.

#### Decisions (and why)

- **Theme merged into Godot's default theme:** the first CI screenshots showed the theme missing (tiny default buttons) on the match HUD and pause menu, because CanvasLayers stop theme inheritance. Merging into the default theme reaches them too. Fixed.
- **Layouts built in code on a minimal .tscn per screen, colors and sizes in `ui.json`:** keeps files small and every number tunable (project rules), and lets the shared theme and helpers serve all screens.
- **Screenshots in CI instead of guessing the look:** Godot cannot run in the cloud session and the user cannot test right now, so the look is reviewed from images rendered in CI at phone resolution.

#### Checked

- New menu flow suite (`tests/ui_flow_test.tscn`) in CI: navigation of every screen, choices stored (crews never the same, formation, court, difficulty, match length), results, player card opens, settings (language, FPS, button size), every translation key has English and French. 137 test checks pass.
- Balance unchanged: 3.67 goals per 150 s AI match.
- Screens reviewed on the CI screenshots in English and French.

#### Next

- The user's phone tests of Phases 3-5 and their remarks.
- Then merges into `main`.
- Then Phase 6 (skills and polish).

### 2026-11-14 — Phase 4: player stats

#### Done

- Branch `feature/player-stats`, created from `feature/five-v-five` (Phase 3). The user asked to start Phase 4 without waiting for the Phase 3 phone test ("don't stop working"); Phase 3 remarks will be fixed when they come. Nothing is merged into `main` yet, per the rule "merge only after the phone test".
- 30 fictional players (`data/players/*.json`) in 6 fictional street crews of 5 (`data/teams/*.json`): Concrete Kings (the user's crew for now, CKS), Rooftop Rebels (RTR), Harbor Hounds (HBH), Neon Nomads (NNM), Parking Lot Pirates (PLP), Sandstorm Strikers (SST). Each player: name, short name, nationality, age, height, preferred foot, weak foot 1-4, natural positions, playstyle (10 kinds), skill-move stars 1-5, special skills, look (skin, hair color, hair style) and 25 attributes 0-99. Overall ratings 74-88; crew averages 79-82. A one-time generator script was used only to create the files; the JSON files are the source of truth. Format: `docs/player-data.md`.
- Code: `Roster` autoload (`scripts/core/roster.gd`) loads all players and crews at start. `PlayerProfile`, `TeamData`, `Ratings`, `StatEffects` in `scripts/data/`.
- `data/config/stat_effects.json`: every attribute maps linearly (40 to 99) to a gameplay number (full list in `docs/player-data.md`): speed, acceleration, turning (balance), dribbling (touch distance, speed and turning with the ball), tight possession (how far the ball can be before it can be stolen), ball control and jump (receiving), interception, shot power, finishing, long shots, low pass, lofted pass, vision (through-pass lead), tackling, balance (harder to tackle), strength (plus a little balance) in shoulder duels, stamina, marking and aggression (AI), goalkeeper reflexes, diving, handling, positioning and kicking. Weak foot: kicks aimed well to the weak side are less accurate.
- `data/config/ratings.json`: overall per role (weights) and position fitness (natural 1.0, adjacent 0.95, other 0.88, keeper outfield 0.75, outfielder in goal 0.6), which also scales a player's attributes out of position. `SlotAssigner` puts the keeper in goal and the 4 others in the slots giving the best total overall, at kick-off and on every formation change.
- Stamina: sprinting drains energy (less with high stamina); below 40 % energy the top speed drops (to 85 % when empty); it recovers when not sprinting.
- Look: players have a head (skin color) and hair (color + style: bald, buzz, short, afro, long, mohawk) and are scaled to their real height.
- HUD: crew short names next to the score; a name tag above the human's player ("number  name  overall") with a stamina bar (green, orange, red). Start screen: new Opponent button cycles the 5 other crews. The away crew wears its alternate kit when the kits clash.
- Match statistics (`scripts/gameplay/match_stats.gd`): shots, keeper saves, passes and passes completed, balls won (tackles, shoulder charges, steals), possession time. For the coming results screen and for balance tests.
- Tests: new stats suite (`tests/stats_test.tscn`) in CI: roster data valid (30 players, 6 crews of 5 with one keeper each, attributes 0-99, known playstyles/skills/positions, overall 60-95), slot assignment for every crew and formation, and that attributes really change play (faster players cover more ground, better dribblers touch closer, finishing, shot power, passing, long shots, stamina, tackling and balance, strength in shoulder duels, keeper attributes, position fitness). The AI match test now plays 3 matches with fixed seeds (repeatable) and prints a balance report.

#### Decisions (and why)

- **JSON files are the source of truth for players; the generator script was one-time only:** content is data, and a player can be edited without code.
- **Every attribute reaches gameplay through `stat_effects.json` (linear 40 to 99):** all stat numbers are tunable without touching code (rule: no magic numbers).
- **Position fitness also scales attributes:** playing out of position has a real cost, so formations and slot choice matter.
- **Phase 4 started before the Phase 3 phone test:** the user's choice, to keep working. Cost: Phase 3 fixes will land on `feature/five-v-five` and need merging into this branch.

#### Balance (data only)

- With stats, AI matches averaged 32.7 shots, 8.3 saves and only 1.67 goals per 150 s: most shots missed.
- Changes: AI aims 55 cm inside the post (was 35); smaller AI aim errors (easy 6, normal 3, hard 1.5 degrees, added to the player's own stat-based error); the AI skips shots at a goal angle under 9 degrees or through a defender unless within 6 m; keeper save chance easy 0.35 / normal 0.55 / hard 0.7.
- Result: 23.7 shots, 9.7 saves, 3.67 goals per 150 s (about 4.4 per 3-minute match). Test matches ended 1-1, 3-2, 2-2.

#### Next

- Wrap up Phase 4, then continue with Phase 5 (menus and UI) while waiting for the user's phone tests of Phases 3 and 4.
- Then fix their remarks, merge into `main`, and continue.

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
