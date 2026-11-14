# Progression and save

Last change: 2026-11-14, Phase 7: save, My Crew, shop, upgrades (branch `feature/progression`, commit `f78448c`)

## What it does now
- Save in `user://savegame.json`, versioned (`save_version` 1): coins, signed players and levels, My Crew (5 starters, bench, formation), unlocked courts, match record (played, wins, draws, losses, goals).
- Writes go through a temporary file. A damaged save is kept as `savegame.bad.json` and a new save starts.
- My Crew starts with 7 fictional rookies (overall 65-75): 5 starters and 2 on the bench. `my_crew` is a team built in code (orange kit, short name YOU); it is never an opponent.
- Coins after every match: win 150, draw 80, loss 50, plus 15 per goal, times 0.8 Easy / 1.0 Normal / 1.4 Hard. Start with 500.
- Shop: 10 free agents (overall 74-89), price 400 + 60 per overall point above 70; two courts to unlock (Rooftop Cage 600, Beach Court 900). Signed players join the bench.
- Upgrades: levels 1 to 5, costs 250, 450, 700, 1000; +2 to every attribute per level, applied through the stat sheet.
- Squad screen: tap two players to swap, INFO opens the card, LV upgrades, warning if no keeper starts.
- Opponent crews never contain players the user can own; only free agents are sold.

## Where it lives
- Code: `scripts/core/save_game.gd` (SaveGame autoload): `load_or_start`, `start_new`, `save`, `swap`, `bench`, `has_keeper_starting`, `my_crew_data`, `player_price`, `buy_player`, `level_of`, `upgrade_cost`, `upgrade`, `court_unlocked`, `court_price`, `unlock_court`, `reward_for`, `record_match`.
- Code: `scripts/core/roster.gd` (Roster autoload): loads players and crews, `free_agent_ids`.
- Code: `scripts/ui/shop.gd` (shop screen), `scripts/ui/squad.gd` (MY CREW screen).
- Numbers: `data/config/progression.json` -> `save_version`, `starting_coins` 500, `starting_players`, `starting_starters`, `starting_courts`, `rewards` (win, draw, loss, per_goal), `difficulty_reward_mult`, `player_price_base` 400, `player_price_per_point` 60, `player_price_reference_overall` 70, `max_level` 5, `level_costs`, `attribute_bonus_per_level` 2, `court_prices` (`rooftop_cage` 600, `beach_sand` 900), `my_crew` (short name, home court, colors).
- Data: `data/players/*.json` (players in no crew are free agents), format in `docs/player-data.md`.
- Tests: `tests/progression_test.gd`: new save, rewards (3-1 win on Normal = 195), shop (too expensive, buying, no double buy, crew players not for sale, price grows with overall), upgrades (cost, +2, max level, reset), squad swaps, court unlock, save and load round trip, damaged save, sand surface, My Crew team (5 starters, keeper wears 1, never an opponent). Also `tests/ui_flow_test.gd` (shop, squad, buying) and `tests/stats_test.gd` (crew players and free agents counted separately).

## History (newest first)
- 2026-11-14: Phase 7: SaveGame, My Crew, squad builder, coins, shop, upgrades, two new courts with surfaces (sand slows the ball), 47 players in total. Why: give a reason to play and build a squad. Branch `feature/progression`, commits `f78448c`, `6f0f2ac` (stats test counts crew players and free agents separately), `7946e17` (docs, version 0.7.0).
- 2026-11-14: Phase 5: first progression-related screens (crew view) and `Roster` use in menus. Branch `feature/menus`, commit `88497f3`.
- 2026-11-14: Phase 4: `Roster` autoload loading 30 players and 6 crews. Branch `feature/player-stats`, commit `d4786b9`.

## Do not undo
- The save is versioned (`progression.json` -> `save_version`). Any format change must bump `save_version` and keep old saves loading.
- Writes go through a temporary file, and a damaged save is kept aside as `savegame.bad.json` before a new one starts. Reason: a crash or bad file never destroys progress silently.
- Opponent crews never contain players the user can own (only free agents are sold). Reason: you never meet your own players in the other team.
- My Crew starts weaker (65-75) than the street crews (about 80). Reason: a reason to earn coins, sign and upgrade.
- Upgrades add to attributes through the stat sheet. Reason: levels change real gameplay with no special-case code.
- `my_crew` is built in code from the save and is never an opponent; the AI match test uses two fixed crews so balance numbers stay comparable.
- Coins, prices, upgrade costs and court prices stay in `progression.json` (no numbers in code).

## How to check after a change
- CI: `tests/progression_test.gd` ("PROGRESSION TESTS DONE: 0 failure"), `tests/ui_flow_test.gd`, `tests/stats_test.gd`.
- Load an old save after a format change (test in `tests/progression_test.gd`; on the phone, update the APK over the old one and keep the save).
- Screenshots: main menu with coins, MY CREW, shop, locked courts.
- Phone test: earn coins, buy, upgrade, close and reopen the app.
