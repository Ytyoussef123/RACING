# Defending

Last change: 2026-11-14, tackle/shoulder code touched by Phase 6 events (branch `feature/polish`, commit `cff05f4`); last dedicated change was the shoulder charge (branch `feature/five-v-five`, commit `1d96a5e`)

## What it does now
- When your team does not have the ball, the four buttons switch to the defense layout: THROUGH -> MATCH-UP, SHOOT -> TACKLE, PASS -> SWITCH, SPRINT -> PRESS (eFootball-style "Dash & Pressure"). Keyboard: R, Space, E (switch: Q), Shift.
- PRESS (hold SPRINT on defense): the selected player goes to take the ball by himself: sprints goal-side of the carrier, then to the ball, auto-tackles in reach. On a loose ball he sprints to where he can meet it.
- MATCH-UP (hold): shadows the carrier goal-side at `match_up_contain_distance` (1.6 m), follows his moves, no auto tackle (tap TACKLE).
- TACKLE: in reach (`tackle_reach` 1.3 m) a chance to knock the ball loose (`tackle_success` 0.55, from tackling and the carrier's balance). A miss slows the tackler. Tackling when nobody has the ball does not stun. A keeper holding the ball in his goal area cannot be tackled.
- Shoulder charge: double-tap the joystick when your side does not have the ball (keyboard F). Within `shoulder_reach` 1.4 m: win and the carrier is pushed, off balance, cannot retake the ball for a moment and the ball comes loose; lose and the charger bounces off and is slowed. Too far: a small lunge and a short slowdown. Decided by strength (plus a little balance): chance = 0.5 + strength difference x 0.01, clamped 0.15 to 0.85. The keeper is protected in his goal area.
- Automatic switch: when defending, control jumps to a teammate who is clearly closer. SWITCH jumps to the teammate nearest the ball.
- Balls won (tackles, shoulder charges, steals) are counted in the match stats.

## Where it lives
- Code: `scripts/gameplay/press_assist.gd` (PressAssist): `apply`. `scripts/gameplay/match_up_assist.gd` (MatchUpAssist): `apply`. `scripts/gameplay/tackle_rules.gd` (TackleRules): `attempt`, `success_chance`, `is_protected`. `scripts/gameplay/shoulder_charge.gd` (ShoulderCharge): `attempt`, `success_chance`, `duel_power`.
- Code: `scripts/gameplay/human_control.gd` (HumanControl, `is_attacking` switches the layout). `scripts/ui/floating_stick.gd` (FloatingStick) detects the double tap.
- Numbers: `data/config/player.json` -> `press_*` (`press_close_distance` 2.0, `press_goal_side_offset` 0.6, `press_tackle_reach_factor` 0.85, `press_tackle_interval` 0.6); `match_up_*` (`match_up_contain_distance` 1.6, `match_up_lead_seconds` 0.25, ...); `tackle_*` (`tackle_reach` 1.3, `tackle_success` 0.55, `tackle_fail_stun` 0.6, `tackle_whiff_stun` 0.35, `tackle_cooldown` 0.8, ...); `shoulder_*` (`shoulder_reach` 1.4, `shoulder_cooldown` 1.0, `shoulder_base_chance` 0.5, `shoulder_strength_factor` 0.01, `shoulder_min_chance` 0.15, `shoulder_max_chance` 0.85, `shoulder_victim_stun` 0.5, ...); `default_strength` 50.
- Numbers: `data/config/stat_effects.json` -> `tackle_success`, `tackle_resist` (balance), `shoulder_balance_weight` 0.3, `intercept_radius`; AI: `mark_distance`, `tackle_attempt_mult`.
- Numbers: `data/config/controls.json` -> `double_tap_seconds` 0.3, `double_tap_distance`, `tap_max_seconds`.
- Tests: `tests/physics_smoke_test.gd`: "shoulder charge: about half the duels won at equal strength", "shoulder charge: out of reach keeps the ball with the carrier", "shoulder charge: the stronger player has more chance", steal checks. `tests/stats_test.tscn`: tackling and balance, strength in shoulder duels.

## History (newest first)
- 2026-11-14: Phase 6: tackle and shoulder events feed sounds and effects (scuff, dust puffs), tackle lean and shoulder lean animations. Branch `feature/polish`, commit `cff05f4`.
- 2026-11-14: Phase 4: tackling, balance and strength stats drive success; shoulder duel uses strength plus a little balance; match stats count balls won. Branch `feature/player-stats`, commits `d4786b9`, `f613738`.
- 2026-11-14: shoulder charge: double-tap the joystick, decided by strength. User asked (like the reference game) for a shoulder charge based on each player's physical strength. Branch `feature/five-v-five`, commit `1d96a5e`.
- 2026-11-14: eFootball-style diamond layout: PRESS on SPRINT ("Dash & Press", user request, from screenshots), MATCH-UP added, SWITCH moved onto PASS on defense; tackling when nobody has the ball no longer stuns. Branch `feature/five-v-five`, commit `6055f1d`.
- 2026-11-14: first PRESS: on defense SHOOT became PRESS (hold, goal-side then tackle by himself). User asked for a button that makes the selected player win the ball. Replaced by the SPRINT version in the next commit. Branch `feature/five-v-five`, commit `6874e1f`.
- 2026-11-14: Phase 3: tackles with a chance, miss slows the tackler, keeper protected in his goal area, automatic switching. Branch `feature/five-v-five`, commit `02cd4ce`.

## Do not undo
- PRESS is the SPRINT button when your team does not have the ball (eFootball-style "Dash & Pressure", user request), and the selected player goes to take the ball by himself. Do not move it back to SHOOT.
- Shoulder charge on a joystick double tap, decided by strength (and a little balance), as the user asked. Do not make it a fixed chance.
- Labels and meaning of the four buttons switch with possession (`HumanControl.is_attacking`); SWITCH is the PASS button on defense.
- A keeper holding the ball in his goal area cannot be tackled or shoulder-charged.
- MATCH-UP does not auto-tackle (tap TACKLE).

## How to check after a change
- CI: `tests/physics_smoke_test.tscn` shoulder and steal checks, `tests/stats_test.tscn`.
- `MATCH BALANCE` line (balls won also in match stats).
- Phone test: hold PRESS, hold MATCH-UP, tap TACKLE, double-tap the joystick near a carrier.
