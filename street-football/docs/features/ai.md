# AI

Last change: 2026-11-14, AI uses skill moves when a defender is within 2 m (branch `feature/polish`, commit `16fa679`)

## What it does now
- Every player, human or AI, is driven by the same `PlayerIntent`. The AI has no cheating inputs.
- Team brain: picks a chaser (closest outfield player) and does greedy marking in its half. Off-ball players hold formation slots that shift with the ball and step away from defenders to get open.
- Ball carrier: shoots in range (aims at the corner away from the keeper, inset from the post), passes when pressed or when a teammate is open further up with a clear lane, else dribbles around defenders. Uses skill moves when a defender is within 2 m.
- Shot choice: skips shots at a goal angle under 9 degrees or through a defender, unless within 6 m.
- Receivers and loose-ball chasers use the same intercept prediction as the human receive assist.
- Keeper: stays between ball and goal, moves across for shots, rushes loose balls near goal, saves (catch or parry) once per shot with a difficulty-based chance, then passes to the most open teammate. Goalkeepers are always AI, also on the human's team.
- Difficulties easy / normal / hard (decision interval, speed factor, shot error, shoot range, pass tendency, tackle chances, keeper save chance, skill tendency). The AI's aim error is added to the player's own stat-based error. Decisions run at the difficulty's interval, movement runs every frame.
- The human's teammates use "normal" (`teammates_difficulty`). The default opponent formation is 1-2-1.

## Where it lives
- Code: `scripts/ai/team_brain.gd` (TeamBrain): `update()`, roles and marks. `scripts/ai/carrier_ai.gd` (CarrierAI): `intent_for()`, `best_pass()`, `lane_clear()`. `scripts/ai/support_ai.gd` (SupportAI): off-ball intent. `scripts/ai/keeper_ai.gd` (KeeperAI): `intent_for()`, `try_save()`. `scripts/ai/formation_positions.gd` (FormationPositions): `slot_target()`, `kickoff_position()`. `scripts/ai/steering.gd` (Steering): `seek()`. `scripts/ai/ai_tuning.gd` (AiTuning): `for_difficulty()`. `scripts/ai/ai_player_state.gd` (AiPlayerState).
- Numbers: `data/config/ai.json`:
  - `difficulties` -> easy / normal / hard: `decision_interval` (0.45 / 0.28 / 0.15), `speed_factor`, `shot_error_degrees` (6 / 3 / 1.5), `shoot_range`, `pass_tendency`, `pass_pressure_distance`, `tackle_attempt_chance`, `tackle_success_bonus`, `keeper_save_chance` (0.35 / 0.55 / 0.7), `skill_tendency` (0.05 / 0.15 / 0.3).
  - Positioning: `role_shift`, `attack_push`, `defend_drop`, `z_ball_follow`, `defend_compress`, `slot_frac_min/max`, `mark_distance`, `mark_zone_frac`, `get_open_distance`.
  - Decisions: `pass_lane_width`, `pass_min_score`, `pass_min_distance`, `pass_max_distance`, `shot_min_frac`, `shot_corner_inset` 0.55, `shot_min_goal_angle_degrees` 9.0, `shot_close_distance` 6.0, `shot_lane_width` 0.5, `shot_charge_min/max`.
  - Keeper: `keeper_line_offset`, `keeper_rush_distance`, `keeper_reach`, `keeper_reach_height`, `keeper_catch_speed`, `keeper_save_min_speed`, `keeper_hold_seconds`, `keeper_parry_lift`, `keeper_parry_spread`.
  - Top level: `teammates_difficulty`, `opponent_formation`.
- Tests: `tests/match_sim_test.gd`: 3 AI-vs-AI matches with fixed seeds (150 s each, fixed 60 fps), checks the ball never stays stuck and players stay in the court, prints the `MATCH BALANCE` line. `tests/stats_test.gd`: keeper attributes.

## History (newest first)
- 2026-11-14: player-motion work (players keep the ball in turns). No AI file changed; balance moved to 5.00 goals, 28.3 shots, 11.0 saves (was 3.33 / 24.3 / 9.0) because attacks last longer. Note: if scoring feels too easy on the phone, raise the keeper save chances in `ai.json`. Branch `feature/player-motion` (no AI commit).
- 2026-11-14: AI uses skill moves (`skill_tendency`). Why: Phase 6. Branch `feature/polish`, commit `16fa679`.
- 2026-11-14: the keeper AI (`scripts/ai/keeper_ai.gd`) now plays the dive animation (`keeper.animate_dive`) and sends a "save" event (`ctx.emit_event("save", ...)`) when it saves. Branch `feature/polish`, commit `cff05f4`.
- 2026-11-14: balance fix: AI shot corner inset 0.55 (was 0.35), smaller aim errors, skips bad shots, keepers save a little less. Why: with stats the AI scored only 1.67 goals per 150 s (32.7 shots, 8.3 saves, most shots missed). Result 3.67 goals, 23.7 shots, 9.7 saves. Branch `feature/player-stats`, commit `9641a8c`.
- 2026-11-14: match stats counted for AI and human (shots, saves, passes, balls won, possession). Branch `feature/player-stats`, commit `f613738`.
- 2026-11-14: AI uses the stat sheet like the human (attributes drive its play). Branch `feature/player-stats`, commit `d4786b9`.
- 2026-11-14: AI receivers and loose-ball chasers use the intercept prediction (`BallPhysics.copy()`); AI follows the dribble and kick rules. Branches `feature/five-v-five`, commits `6055f1d` (and `1d96a5e` for touch dribbling rules, same rules for the AI).
- 2026-11-14: first AI: team brain, carrier, support, keeper, difficulties. Why: Phase 3 (5v5). Branch `feature/five-v-five`, commit `02cd4ce`.
- 2026-11-14: Phase 1 commit `3193378` (branch `main`) only created the empty folder (`scripts/ai/.gitkeep`).

## Do not undo
- Balance is measured by the CI AI-match test (`MATCH BALANCE`, 3 fixed seeds). History of the numbers per 150-second match:
  - after stats: 1.67 goals (too low) -> fixed with `shot_corner_inset` 0.55, smaller aim errors, skipping shots under 9 degrees goal angle or through a defender (unless within 6 m), lower keeper save chances -> 3.67 goals, 23.7 shots, 9.7 saves;
  - after skill moves: 3.33 goals, 24.3 shots, 9.0 saves;
  - after the player-motion work: 5.00 goals, 28.3 shots, 11.0 saves.
  With 3 matches the goal count moves a lot between runs (1.67 to 5.00 during the player-motion work). Judge by shots and saves too, and by the phone.
- The AI uses the same `PlayerIntent` path as the human: no cheating inputs. Difficulty only changes reaction time, speed factor, aim error, tendencies and keeper save chance.
- Decisions at an interval, movement every frame: difficulty stays tunable and movement smooth.
- The AI match test uses two fixed crews (not My Crew), so the balance numbers stay comparable.
- Keepers are always AI.

## How to check after a change
- CI test `tests/match_sim_test.tscn`: the `MATCH BALANCE` line (goals, shots, saves, longest stuck ball) and the 3 match results; compare with the numbers above.
- Other CI suites pass (physics, stats, progression, menus).
- Phone test: play each difficulty; check scoring is not too easy or too hard.
