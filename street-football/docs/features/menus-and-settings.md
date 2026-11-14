# Menus, settings, translations

Last change: 2026-11-14, camera view row in Settings (branch `feature/broadcast-camera`, commit `a66b096`)

## What it does now
- Start scene: main menu (`scenes/menus/main_menu.tscn`) with QUICK MATCH, MY CREW, SHOP, SETTINGS, a tilted "5v5" tag, version and device info, coins.
- Quick match in 3 steps: crews (< and >, team cards, tap a player for his card), formation (5 chips and a mini court), court and rules (court, difficulty Easy/Normal/Hard, length 3/4/5 minutes), then PLAY.
- Results screen: YOU WIN / DRAW / YOU LOSE, score, goals, match stats, coins earned, REMATCH and MAIN MENU.
- My crew screen, shop screen, player card (25 attributes as colored bars).
- Settings, saved in `user://settings.cfg`: language (English / Français), show FPS, touch button size (small / normal / large), Sound on/off, Music on/off, camera view (Close / Normal / Wide).
- Android back button: quits on the main menu, goes back on other screens, pauses or resumes in the match.
- Street theme: dark buttons with an orange tape stripe, orange main buttons, cyan chips, rounded cards, drawn asphalt background.
- All visible text is translated (English and French) from `locale/strings.csv`.

## Where it lives
- Code: `scripts/ui/menu_screen.gd` (MenuScreen): base class (`build_frame`, `add_footer_button`, `go_back`).
- Code: `scripts/ui/ui_build.gd` (UiBuild): helpers that build layouts in code.
- Code: screens and components in `scripts/ui/` (TeamCard, PlayerCard, FormationPreview, StatBar, PauseMenu, `shop.gd`, `squad.gd`); a minimal .tscn per screen in `scenes/menus/`.
- Code: `scripts/core/screens.gd` (Screens autoload): `go(screen_id)`; `scripts/core/ui_theme.gd` (UiTheme): builds the theme, merges it into `ThemeDB.get_default_theme()`, `color`, `font_size`; `scripts/core/settings.gd` (Settings): `set_language`, `set_show_fps`, `set_controls_size`, `set_sound_on`, `set_music_on`, `set_camera_view`, `save`, FPS overlay.
- Numbers: `data/config/ui.json` -> `screens` (scene paths), `colors`, `font_sizes`, `button_min_height` 104, `corner_radius`, `screen_margin_x/y`, `match_minutes` [3, 4, 5], `controls_scales`, `stat_bar_colors`.
- Numbers: `data/config/camera.json` -> `presets`, `default_preset` (Settings row default).
- Translations: `locale/strings.csv` (columns `keys,en,fr`).
- Tests: `tests/ui_flow_test.gd`: navigation of every screen, choices stored, results, player card, settings (language, FPS, button size, sound, music, camera chips), every translation key has English and French. Look: `tests/screenshot_tour.gd`.

## History (newest first)
- 2026-11-14: New Camera row in Settings (Close / Normal / Wide), saved with the other settings; the menu flow test presses the camera chips. Branch `feature/broadcast-camera`, commit `a66b096`.
- 2026-11-14: Phase 7: coins on the main menu and results, SHOP screen, MY CREW screen with swaps and upgrades, locked courts greyed with their price. Branch `feature/progression`, commits `f78448c`, `7946e17`.
- 2026-11-14: Phase 6: Sound and Music rows in Settings (saved); UI click sound. Branch `feature/polish`, commits `cff05f4`, `16fa679`.
- 2026-11-14: Theme applied everywhere, main menu tag. Why: CI screenshots showed tiny default buttons on the match HUD and pause menu (see "Do not undo"). Branch `feature/menus`, commit `70b5967`.
- 2026-11-14: Phase 5: all menu screens, results, player card, settings, pause menu, theme, about 90 new texts in English and French, CI screenshots. Branch `feature/menus`, commit `88497f3`.
- 2026-11-14: Menu pieces tied to earlier commits (team and crew display, PRESS and shoulder charge texts) in the touched `scripts/ui` files. Branches `feature/five-v-five` (`02cd4ce`, `6874e1f`, `6055f1d`, `1d96a5e`), `feature/player-stats` (`d4786b9`).
- 2026-11-14: Renamed the touch classes (`VirtualJoystick` -> `FloatingStick`) and `draw()` -> `render()`. Branch `main`, commits `bbb81c6`, `2e45e3b`.
- 2026-11-14: Phase 2: simple start screen with two Play buttons and a language button. Branch `main`, commit `19add2a`.
- 2026-11-14: Phase 1: boot test screen with tap counter, EN/FR switch, FPS counter, device info; `locale/strings.csv`. Branch `main`, commit `3193378`.

## Do not undo
- Menu layouts are built in code (UiBuild) on top of a minimal .tscn per screen; colors and sizes are in `ui.json`. Reason: small files, every number tunable, shared theme and helpers.
- The theme is merged into ThemeDB's default theme. Reason: nodes under a CanvasLayer or a plain Node did not inherit it (seen on CI screenshots: tiny default buttons on the HUD and pause menu).
- A helper named `draw()` clashed with the CanvasItem `draw` signal and was renamed `render()`. Check the Godot class list before naming.
- All visible text is translated (`locale/strings.csv`, English and French); never hard-code text. The test checks every key has both languages.
- Settings are saved in `user://settings.cfg`: language, FPS counter, sound, music, button size, camera view (added 2026-11-14).
- Lesson: a Python edit once duplicated a block of `match_setup.gd` because its markers were in the wrong order. Check marker order before slicing a file.
- At the start of the CI import Godot logs "Cannot open file strings.en.translation" once (translations are generated during that import). Harmless.

## How to check after a change
- CI: `tests/ui_flow_test.gd` passes ("UI TESTS DONE: 0 failure"); no script errors.
- Screenshots: decode with `.github/scripts/decode_screenshots.py` and check every screen, in English and French, for text that does not fit.
- Phone test: back button on each screen, settings kept after restarting the app.
