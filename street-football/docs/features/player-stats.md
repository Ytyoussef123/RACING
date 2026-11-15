# Player stats

Last change: 2026-11-15, new stat effect `air_control_chance` from ball control (branch `feature/lofted-pass`, commit `583d616`). Before that: 2026-11-14, Phase 7 added 17 free agents (7 rookies for My Crew, 10 in the shop) and upgrades through the stat sheet (branch `feature/progression`, commits `f78448c`, `6f0f2ac`, `7946e17`)

## What it does now
- Players have 25 attributes (0..99). They reach gameplay only through the stat sheet: `StatEffects.build_sheet(profile, role)` is built in `Player` and read with `Player.stat(effect, fallback)`. The fallback is the neutral value for test players.
- Each effect maps one attribute linearly from 40 (low value) to 99 (high value), clamped. Names ending in `_mult` multiply the base number in `data/config/player.json`.
- The attribute is first scaled by the player's position fitness: natural 1.0, adjacent 0.95, other 0.88, keeper outfield 0.75, outfielder in goal 0.6.
- Overall rating per role (GK, DEF, MID, WING, ATT) = weighted average of attributes x position fitness (`ratings.json` -> `weights`).
- Effects (full list in `docs/player-data.md`): speed, acceleration, turning, dribbling (touch distance, speed and turning with the ball), tight possession, ball control, jump, interception, shot power, finishing, long shots, low pass, lofted pass, vision, tackling, balance, strength (shoulder duels), stamina, marking, aggression, goalkeeper reflexes, diving, handling, positioning, kicking. Weak foot: kicks aimed to the weak side are less accurate (`weak_foot_error_mult`).
- Air first touch: `air_control_chance` (`stat_effects.json`, from `ball_control`, 0.55 at 40 to 0.95 at 99) is the chance of a clean first touch on a ball coming down (chest, thigh or foot); fallback 0.8 for players without a profile (`player.json` -> `air_control_chance`). Used by `AirControl` (see `passing-and-receiving.md`).
- Stamina: sprinting drains energy (less with high stamina); below 40 % energy the top speed drops to 85 % when empty; it recovers when not sprinting.
- Upgrades (levels 1-5) add +2 to every attribute per level through the stat sheet.
- Roster: 47 fictional players: 30 in the 6 crews (5 each, one keeper each) and 17 free agents (7 rookies for My Crew, 10 in the shop). Crew overall 74-88 (crew averages 79-82), rookies 65-75, shop players 74-89.
- Player profile: name, short name, nationality, age, height (the body is scaled to it), preferred foot, weak foot 1-4, natural positions, playstyle (10 kinds), skill-move stars 1-5, special skills, look (skin, hair color, hair style).
- Slots: `SlotAssigner` puts the keeper in goal and the 4 others in the formation slots giving the best total overall, at kick-off and on every formation change.

## Where it lives
- Code: `scripts/data/stat_effects.gd` (StatEffects): `build_sheet()`, `num()`. `scripts/data/ratings.gd` (Ratings): `position_fitness()`, `overall()`, `best_overall()`. `scripts/data/player_profile.gd` (PlayerProfile): `attr()`, `is_keeper()`, `look_color()`. `scripts/gameplay/slot_assigner.gd` (SlotAssigner): `assign()`. `scripts/gameplay/player.gd` (Player): `stat()`. `scripts/core/roster.gd` (Roster autoload): loads players and crews, `free_agent_ids()`.
- Data: `data/players/*.json` (one file per player), `data/teams/*.json` (6 crews). Format: `docs/player-data.md`. The JSON files are the source of truth (the generator was one-time).
- Numbers: `data/config/stat_effects.json` -> `stat_low` 40, `stat_high` 99, `effects` (run_speed_mult, sprint_speed_mult, acceleration_mult, turn_speed_mult, dribble_*, control_*, shot_*, pass_error_degrees, tackle_success, stamina_drain, keeper_* ...), `long_shot_distance` 12, `weak_side_degrees` 35, `weak_foot_error_mult` [2.6, 2.0, 1.5, 1.15], `shoulder_balance_weight` 0.3, `energy_recover_per_second` 0.04, `low_energy_threshold` 0.4, `low_energy_speed_mult` 0.85.
- Numbers: `data/config/ratings.json` -> `weights`, `position_fitness`, `adjacent`, `positions`, `playstyles`, `special_skills`.
- Tests: `tests/stats_test.gd`: roster data valid (47 players, 17 free agents, 6 crews of 5 with one keeper, attributes 0-99, known playstyles, skills and positions, overall 60-95), slot assignment for every crew and formation, and that attributes change play (speed, dribbling, finishing, stamina, tackling and balance, keeper attributes, position fitness). `tests/progression_test.gd`: upgrades add +2 per level.

## History (newest first)
- 2026-11-15: new stat effect `air_control_chance` (`ball_control`, 0.55 to 0.95) for the first touch on a ball coming down; the `lofted_pass` stat (`through_error_degrees`) also sets the aim error of lofted kicks. Why: user decision (planning talk): receiving a high ball by chest, thigh or foot control, harder when strong or high; better ball control makes a clean touch more likely. Branch `feature/lofted-pass`, commit `583d616`. Tests: air control checks in `tests/lofted_pass_test.gd`.
- 2026-11-14: Phase 7: 7 rookies and 10 shop players (free agents), upgrades +2 per attribute per level, 47 players in total. Branch `feature/progression`, commit `f78448c`; docs `7946e17`.
- 2026-11-14: stats test fixed: it expected 30 players, so it now counts crew players and free agents separately. Branch `feature/progression`, commit `6f0f2ac`.
- 2026-11-14: sprint knock-on flag set by touches only; docs for player motion. Branch `feature/player-motion`, commit `1690191`.
- 2026-11-14: Phase 4: 30 fictional players, 6 crews, `StatEffects`, `Ratings`, position fitness, `SlotAssigner`, stamina, stats tests. The user asked to start without waiting for the Phase 3 phone test. Branch `feature/player-stats`, commit `d4786b9`.
- 2026-11-14: Phase 1 commit `3193378` (branch `main`) only created the empty folder (`data/players/.gitkeep`).

## Do not undo
- Attributes (0..99) reach gameplay only through the stat sheet (`StatEffects.build_sheet`, `Player.stat`): all stat numbers are tunable in `stat_effects.json`, with no special-case code. Upgrades rely on this too.
- A linear map from 40 to 99 for every effect.
- Position fitness also scales attributes: playing out of position has a real cost, so formations and slot choice matter.
- 47 fictional players: 30 in the 6 crews, 17 free agents. Never real names, real clubs or brands.
- Crew players are never sold, so you never meet your own players in the other team. Only free agents are sold or given to My Crew.
- JSON files are the source of truth for players; the generator script was one-time only.
- The stats test once expected 30 players and failed after Phase 7: it must count crew players and free agents separately.

## How to check after a change
- CI suite `tests/stats_test.tscn` and `tests/progression_test.tscn` pass.
- `MATCH BALANCE` line of `tests/match_sim_test.tscn` after any change of the effect numbers.
- Screenshot tour: player card (25 attribute bars) and My Crew screen.
- Phone test: differences between fast and slow players, good and bad dribblers.
