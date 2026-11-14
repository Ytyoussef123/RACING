# Touch controls and match HUD

Last change: 2026-11-14, skill moves on a joystick flick, name callouts above the player (branch `feature/polish`, commit `16fa679`)

## What it does now
- Floating joystick on the left part of the screen (it appears under the thumb). Four buttons in an eFootball-style diamond on the right.
- Attack layout (our side has the ball, or touched the loose ball last): THROUGH top-left, SHOOT top-right, PASS bottom-left, SPRINT bottom-right.
- Defense layout otherwise: MATCH-UP top-left, TACKLE top-right, SWITCH bottom-left, PRESS bottom-right (the SPRINT button becomes PRESS).
- SHOOT is held to charge, with a power bar above the player. Other buttons: tap or hold as in the README.
- Double tap on the joystick when our side does not have the ball = shoulder charge.
- Flick of the joystick with the ball (quick swipe and release, under 0.22 s) = skill move.
- Touch button size follows the Settings choice (small 0.85 / normal 1.0 / large 1.18).
- Keyboard on PC: WASD or arrows, R, Space, E, Shift, Q (switch), F (shoulder charge), C (skill move).
- HUD: score and clock, crew short names, court name, PAUSE button top-left (RESUME, FORMATION, QUIT MATCH), name tag above the human player ("number  name  overall") with a stamina bar, power bar, centered messages (GOAL!, OUT, FULL TIME), callouts above a player (skill move names).

## Where it lives
- Code: `scripts/ui/touch_controls.gd` (TouchControls): handles every finger itself (multi-touch), `get_move_vector`, `is_held`, `consume_press`, `consume_stick_flick`, `consume_stick_double_tap`, `set_defense_layout`.
- Code: `scripts/ui/floating_stick.gd` (FloatingStick): joystick, detects flick and double tap (`begin`, `drag`, `end`, `consume_flick`, `consume_double_tap`).
- Code: `scripts/ui/action_button.gd` (ActionButton): one button (`contains`, `press`, `release`, `consume_press`, `render`).
- Code: `scripts/ui/match_hud.gd` (MatchHud): `set_score`, `set_clock`, `set_team_names`, `show_message`, `show_callout`, `update_power`, `update_player_tag`.
- Code: `scripts/gameplay/human_input.gd` (HumanInput): `read(attacking)` turns touch and keyboard into a `PlayerIntent`.
- Code: `scripts/gameplay/human_control.gd` (HumanControl): `is_attacking`, `is_receiving`, selection of the controlled player.
- Scenes: `scenes/ui/`.
- Numbers: `data/config/controls.json` -> joystick (`joystick_zone_width` 0.45, `joystick_zone_top`, `joystick_rest_position` [0.15, 0.72], `joystick_radius` 0.13, `joystick_dead_zone`), buttons (`*_position` and `*_radius`: shoot [0.925, 0.5], through [0.79, 0.56], pass [0.765, 0.83], sprint [0.915, 0.8]; `button_hit_scale` 1.25), gestures (`double_tap_seconds` 0.3, `tap_max_seconds` 0.25, `double_tap_distance` 0.15, `flick_max_seconds` 0.22, `flick_min_fraction` 0.55). Positions are screen fractions, radii are fractions of the short side.
- Numbers: `data/config/ui.json` -> `controls_scales`. `data/config/animation.json` -> `message_pop_scale`, `message_pop_seconds`.
- Tests: `tests/ui_flow_test.gd` (settings: button size), `tests/physics_smoke_test.gd` (shoulder charge, pass and receive behavior); look checked with `tests/screenshot_tour.gd` (match HUD).

## History (newest first)
- 2026-11-14: Skill moves on a joystick flick (`consume_stick_flick`, keyboard C); move names pop above the player with `show_callout`. Proposal made without an extra button (the direction picks the move); it waits for the user's opinion. Branch `feature/polish`, commits `16fa679`.
- 2026-11-14: Phase 6 part 1: GOAL! text pops (message pop numbers in `animation.json`). Branch `feature/polish`, commit `cff05f4`.
- 2026-11-14: Phase 5: PAUSE button replaces MENU; touch button size from Settings; Android back button pauses or resumes in the match. Branch `feature/menus`, commit `88497f3`.
- 2026-11-14: Phase 4: crew short names next to the score, name tag above the human's player with a stamina bar. Branch `feature/player-stats`, commit `d4786b9`.
- 2026-11-14: Double tap on the joystick = shoulder charge (`double_tap_seconds` 0.3, keyboard F). Why: user feedback, wanted as in eFootball. Branch `feature/five-v-five`, commit `1d96a5e`.
- 2026-11-14: Button layout changed to the eFootball diamond; labels switch with possession; SPRINT becomes PRESS on defense; the separate SWITCH button removed (SWITCH is the PASS button on defense, Q on keyboard); THROUGH and MATCH-UP added. Why: the user sent eFootball screenshots and asked for it. Branch `feature/five-v-five`, commit `6055f1d`.
- 2026-11-14: PRESS first appeared on the SHOOT button on defense (PASS became TACKLE). Why: user asked for a button to win the ball. Replaced by the diamond layout the same day. Branch `feature/five-v-five`, commit `6874e1f`.
- 2026-11-14: Phase 3: SWITCH button, keys E and Q, MENU top-left, formation button top-right, score and clock. Branch `feature/five-v-five`, commit `02cd4ce`.
- 2026-11-14: Renamed `VirtualJoystick` to `FloatingStick` and `TouchButton` to `ActionButton`. Why: `class_name VirtualJoystick` was hidden by Godot 4.7's built-in class and broke the match scene (found by CI). Branch `main`, commit `bbb81c6`.
- 2026-11-14: Renamed helper `draw()` to `render()`. Why: it clashed with the CanvasItem `draw` signal (compile error found by CI). Branch `main`, commit `2e45e3b`.
- 2026-11-14: Phase 2: floating joystick, SHOOT (hold to charge), PASS, SPRINT, keyboard keys; every finger handled by the code itself. Branch `main`, commit `19add2a`.

## Do not undo
- The button layout follows the eFootball mobile layout (attack: shoot, pass, through, sprint; defense: the SPRINT button becomes PRESS, plus match-up, tackle, switch). The user asked for it with screenshots.
- Button positions and sizes are screen fractions in `controls.json` (not pixels), so they fit every phone.
- Double tap on the joystick = shoulder charge on defense; joystick flick = skill move.
- Class names are `FloatingStick` and `ActionButton`: a class named `VirtualJoystick` clashed with a Godot 4.7 built-in class (naming trap in `CLAUDE.md`). Do not name a method like a built-in signal either (`draw` -> `render`).
- Touch controls handle every finger themselves (reliable multi-touch).
- Planned next, from the user's video, not done yet: mini-map, name tags for the controlled player and the opponent ball carrier, a marker over the next player to switch to, CLEAR instead of SHOOT in our own half; swipe variations on buttons later.

## How to check after a change
- CI: `tests/ui_flow_test.gd` and `tests/physics_smoke_test.gd` pass; no script errors in the log (a class name clash shows up there, not in the physics tests).
- Screenshots: decode with `.github/scripts/decode_screenshots.py` and look at the match HUD and buttons.
- Phone test: both layouts, multi-touch (stick and buttons together), double tap, flick, small and large button sizes.
