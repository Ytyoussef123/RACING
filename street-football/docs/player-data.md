# Player and team data

Everything about players and crews is data: no code change is needed to add, edit or rebalance them.
All players, crews and names are fictional. Never use real players, clubs, logos or brands.

## Add a player: `data/players/<id>.json`

The file name (without `.json`) is the player id, for example `teo_varmanetti`.

| Field | Meaning |
|---|---|
| `name`, `short_name` | Full name and the short form shown in the match (`T. Varmanetti`). |
| `nationality`, `age`, `height_cm` | Identity. Height also scales the player's body. |
| `preferred_foot` | `right` or `left`. |
| `weak_foot` | 1–4: accuracy with the other foot (kicks aimed well to that side are less precise). |
| `positions` | Natural positions, best first: `GK`, `DEF`, `MID`, `WING`, `ATT`. |
| `playstyle` | One of the ids in `data/config/ratings.json` → `playstyles`. |
| `skill_moves` | 1–5 stars (used by skill moves in Phase 6). |
| `special_skills` | Ids from `ratings.json` → `special_skills` (`flip_flap`, `rainbow`, `nutmeg`, `rabona`, `first_time_shot`, `roulette`, `heel_flick`). |
| `look` | `skin` and `hair` colors (`#rrggbb`), `hair_style`: `bald`, `buzz`, `short`, `afro`, `long`, `mohawk`. |
| `attributes` | The 25 attributes below, 0–99. |

Attributes:

- Attack: `finishing`, `shot_power`, `long_shots`, `heading`
- Ball control: `dribbling`, `ball_control`, `tight_possession`
- Passing: `low_pass`, `lofted_pass`, `vision`
- Physical: `speed`, `acceleration`, `stamina`, `strength`, `balance`, `jump`
- Defense: `tackling`, `interception`, `marking`, `aggression`
- Goalkeeper: `gk_reflexes`, `gk_diving`, `gk_handling`, `gk_positioning`, `gk_kicking`

## Add a crew: `data/teams/<id>.json`

`name`, `short_name` (3 letters for the score bar), `home_court` (a court id), `colors`
(`kit`, `keeper`, and `alt_kit` / `alt_keeper` used when the kits clash), and `players`: five
entries `{"id": "<player id>", "number": <shirt number>}`, exactly one of them a goalkeeper.

## Free agents

A player whose id is in no crew file is a free agent (`Roster.free_agent_ids`). Free agents are
your 7 starting rookies (overall 65-75) and the shop players (overall 74-89). Add a player file and
leave him out of every crew to make him a free agent. Shop price = 400 + 60 per overall point above
70 (`data/config/progression.json`). Crew players are never sold, so they never appear in your squad.

## How attributes change the game: `data/config/stat_effects.json`

Each effect maps one attribute linearly from `low` (at 40) to `high` (at 99), clamped.
Names ending in `_mult` multiply the base number from `player.json`; the others are the value itself.

| Effect | Attribute | What it changes |
|---|---|---|
| `run_speed_mult`, `sprint_speed_mult` | speed | Top speed (keepers: `gk_positioning`) |
| `acceleration_mult` | acceleration | How fast top speed is reached |
| `turn_speed_mult` | balance | Turning without the ball |
| `dribble_turn_speed_mult`, `dribble_speed_factor`, `dribble_touch_extra_mult` | dribbling | Turning and speed with the ball, how far touches go |
| `dribble_exposed_distance` | tight_possession | How far ahead the ball can be before it can be stolen |
| `control_radius`, `control_max_relative_speed` | ball_control | Receiving the ball |
| `intercept_radius` | interception | Cutting out the opponent's passes |
| `control_max_ball_height` | jump | Controlling high balls |
| `shot_speed_mult` | shot_power | Shot speed |
| `shot_error_degrees` | finishing | Shot accuracy |
| `long_shot_error_per_meter` | long_shots | Extra error beyond 12 m |
| `pass_error_degrees` | low_pass | Pass accuracy |
| `through_error_degrees` | lofted_pass | Through-pass accuracy |
| `through_lead_mult` | vision | How far into the run a through pass is played |
| `tackle_success` | tackling | Chance to win the ball in a tackle |
| `tackle_resist` | balance | Carrier: harder to tackle |
| `stamina_drain` | stamina | Energy used per second of sprinting |
| `mark_distance` | marking | How tight the AI marks |
| `tackle_attempt_mult` | aggression | How often the AI goes into tackles |
| `keeper_save_mult`, `keeper_reach`, `keeper_catch_speed` | reflexes, diving, handling | Saves |
| `keeper_move_mult` | gk_positioning | Keeper movement |
| `keeper_kick_error_degrees` | gk_kicking | Keeper pass accuracy |

Also in that file: weak-foot error multipliers, the shoulder-duel balance weight, and the stamina
recovery and tiredness numbers. Strength (and a little balance) decides shoulder duels.

## Overall rating and positions: `data/config/ratings.json`

The overall rating for a role is a weighted average of attributes (`weights`), multiplied by the
position fitness: 1.0 in a natural position, 0.95 adjacent, 0.88 elsewhere, 0.75 for a keeper
outfield, 0.6 for an outfielder in goal. The same fitness scales all attributes when a player plays
out of position. When a formation is chosen, players are placed in the slots that give the best
total overall (the keeper always in goal).
