# Skill moves

Last change: 2026-11-15, the forward flick no longer makes a knock-on (the knock-on is now the joystick double pull) (branch `feature/speed-modes`, commit `a89cab9`)

## What it does now
- A skill move is a quick flick of the joystick (swipe and release in under 0.22 s) while the player has the ball. Keyboard: C.
- The flick direction compared to where the player faces picks the move: forward (under 50 degrees), back (over 130 degrees), otherwise side.
  - Forward: rainbow flick over a defender within 3 m, nutmeg through a defender within 1.6 m (the ball passes through him), otherwise no move. The single knock-on was removed from the flick; the knock-on is now the joystick double pull (see `touch-controls-and-hud.md`, `dribbling.md`).
  - A flick that makes no move gives the skill cooldown back (`BallHandling._play_queued`).
  - Side: elastico or step-over (flip_flap is the special skill for the elastico).
  - Back: heel-flick pass to a teammate behind (within 10 m), roulette or drag-back.
- Each move needs a minimum number of skill-move stars (1 to 5, from the player's profile). The special moves also need the special skill: flip_flap, rainbow, nutmeg, roulette, heel_flick.
- Success chance = 0.45 + 0.1 per star + 0.004 per dribbling point above 75, at most 0.97. A miss is a bad touch: the ball is lost.
- A good move can freeze defenders within 2.6 m for 0.55 s (chance grows with stars).
- After a move the ball is played to the player himself, so the receive assist runs him onto it. The move name pops up above the player (for example "Elastico!", "Lost it!").
- Other special skills: `first_time_shot` makes one-touch shots more accurate (error x 0.6); `rabona` removes the weak-foot penalty.
- The AI's forward skill attempt now does nothing when nobody is in the way (cooldown given back).
- The AI uses skill moves when a defender is within 2 m, with a chance per decision (`skill_tendency` easy 0.05, normal 0.15, hard 0.3, scaled by the player's stars).
- A move has a 1.0 s cooldown. Each move briefly blocks the player from retaking the ball (`retake_block_seconds`).

## Where it lives
- Code: `scripts/gameplay/skill_moves.gd` (SkillMoves): `perform()` picks and plays the move and emits a "skill" match event, `success_chance()`.
- Code: `scripts/ui/floating_stick.gd` (FloatingStick) detects the flick (`consume_flick()`); `scripts/gameplay/human_input.gd` sets `PlayerIntent.skill`; `scripts/gameplay/ball_handling.gd` calls `SkillMoves.perform`.
- Code: `scripts/ai/carrier_ai.gd` (CarrierAI) tries a skill move when the pressure is under `skills.json` -> `ai_skill_pressure` (2.0) and a random draw is under the difficulty's `skill_tendency` times the player's skill stars / 5; the direction comes from `_skill_direction()`.
- Code: the skill animation is in `scripts/gameplay/player_actions.gd` (PlayerActions, action "skill").
- Numbers: `data/config/skills.json` -> `forward_degrees`, `back_degrees`, `cooldown`, `base_success`, `success_per_star`, `success_per_dribbling_point`, `dribbling_reference`, `max_success`, `min_stars` (per move; the `knock_on` entry was removed on 2026-11-15, as were `knock_on_speed` and `retake_block_seconds.knock_on`), `fool_*` (radius 2.6, base 0.3, per star 0.12, seconds 0.55), the move speeds (`rainbow_forward_speed` 7.0, `rainbow_lift` 5.5, `nutmeg_speed` 6.5, `heel_flick_speed` 9.0 ...), `rainbow_defender_distance` 3.0, `nutmeg_defender_distance` 1.6, `heel_flick_max_distance` 10.0, `bad_touch_speed`, `first_time_shot_error_mult` 0.6, `retake_block_seconds`.
- Numbers: `data/config/controls.json` -> `flick_max_seconds` 0.22, `flick_min_fraction` 0.55.
- Numbers: `data/config/ai.json` -> difficulties -> `skill_tendency`; `skills.json` -> `ai_skill_pressure` 2.0.
- Numbers: `data/config/ratings.json` -> `special_skills` list.
- Tests: `tests/physics_smoke_test.gd` `_test_skill_moves`: elastico, nutmeg, rainbow, drag-back, failed move ("skill: a failed move is a bad touch (ball lost)" now uses a side flick), "skill: forward flick with nobody close is no move (the knock-on is the double pull)". The `SKILL_KNOCK_ON` string was removed. `tests/stats_test.gd`: special skills in the roster data are known names.

## History (newest first)
- 2026-11-15: the forward flick no longer makes a single knock-on push; forward = rainbow or nutmeg near a defender, otherwise no move (cooldown given back). Removed the `knock_on` entries in `skills.json` and the `SKILL_KNOCK_ON` string. Why: the user agreed to remove it, the knock-on is now the joystick double pull. Branch `feature/speed-modes`, commit `a89cab9`.
- 2026-11-14: skill moves on a joystick flick, special skills in play, AI uses moves when a defender is within 2 m, move name pop-ups, skill-move animation, 6 new tests. Why: Phase 6 (skills and polish). Branch `feature/polish`, commit `16fa679`.
- 2026-11-14: the earlier controls the flick builds on (shoulder charge and touch dribbling `1d96a5e`, button layout and receive assist `6055f1d`, 5v5 intent path `02cd4ce`, first touch input `19add2a`). These commits touch the same files but are not skill moves themselves. Branches `feature/five-v-five` (first three) and `main` (`19add2a`).

## Do not undo
- Skill moves are done by a joystick flick with the ball (no extra button; direction picks the move). This is a proposal: the user has not yet given an opinion on the flick control (on 2026-11-15 he agreed to remove the forward knock-on from it, nothing more). Do not change it or add a button without asking.
- A failed move loses the ball: gives risk against reward, with stars and dribbling raising the odds.
- After a move the ball is played to the player himself (he stays the pass target), so the receive assist runs him onto it and nobody of his team blocks it.
- Skill-move numbers stay in `skills.json` (no magic numbers in code).

## How to check after a change
- CI test `tests/physics_smoke_test.tscn` (the skill-move checks) must pass.
- `MATCH BALANCE` line of `tests/match_sim_test.tscn`: after skill moves it was 3.33 goals, 24.3 shots, 9.0 saves; keep it near that.
- Screenshot tour and motion study images (decode with `.github/scripts/decode_screenshots.py`) if the animation changed.
- Phone test: flick in each direction with the ball; check the move names pop up.
