# CLAUDE.md — Street Football 5v5

Street / neighborhood 5v5 football for Android, built with **Godot 4.7.2** and **GDScript**.
This project lives in `street-football/`. The rest of the repository is another game (Corniche Rush): don't touch it.

## Project rules

1. **Fictional content only.** Never use real players, real clubs, logos, kits, stadiums or licensed brands. All names, looks and nationalities are invented.
2. **No magic numbers in code.** Every gameplay number (speeds, forces, timings, stat formulas, AI weights) goes in `data/config/*.json`, read through the `Config` autoload (`Config.get_value(section, key, default)`). The default in code is only a safety net.
3. **Content is data.** Players, courts and formations are data files in `data/`, never hard-coded.
4. **Small files, one job each.** One scene or script per responsibility. Split a script before it grows past ~300 lines.
5. **All UI text is translated.** Put the key in `locale/strings.csv` (columns `keys,en,fr`) and use the key in the scene or `tr("KEY")` in code. Never hard-code visible text.
6. **Phones first.** Target 60 FPS on mid-range Android (30 FPS fallback). Use the Compatibility renderer (OpenGL ES 3) and simple shaders. Test on the real phone: emulators accept things real phones reject.
7. **Free / original assets only.** List every asset and its license in `README.md` before committing it.
8. **After each feature:** test it (the CI build must pass, then the user tests on the phone), update `JOURNAL.md`, commit.
9. **Phases:** work phase by phase (see `JOURNAL.md`). Stop at the end of each phase and wait for the user's phone test. Ask before any decision that is hard to undo.
10. **Keep the code ready for online play later.** Gameplay logic works on the flat ground plane (x, z) with ball height separate, and the match simulation is kept apart from input and rendering.

## Folder structure

```
street-football/
  project.godot, export_presets.cfg, icon.svg
  scenes/        .tscn files: boot/, match/, menus/, court/, player/, ball/, ui/
  scripts/
    core/        autoloads: Config, FrameRate (later: GameState, SaveSystem)
    gameplay/    match rules, score, timer, kick-off
    physics/     ball and player movement
    ai/          team AI, goalkeeper AI
    data/        loaders for players, courts, formations
    ui/          screens, HUD, touch controls
  data/
    config/      every tuning number (JSON)
    players/     one JSON file per fictional player
    courts/      one JSON file per court
    formations/  one JSON file per formation
  locale/        strings.csv (en, fr)
  assets/        art/, audio/, fonts/ (free/original only)
  docs/          design notes, Android export guide
```

`core/` holds the autoloads; `data/config/` is the single home for numbers (rule 2).

## Git workflow

- One branch per feature: `feature/<name>` (for example `feature/ball-physics`).
- Merge into `main` only after the CI APK build passes and the user has tested it on the phone.
- Clear commit messages: what changed and why.
- The CI workflow `.github/workflows/street-football-apk.yml` builds a debug APK on every push and fails on GDScript errors.
- `.github/keystore/debug.keystore` is a **debug-only** key (password `android`). Release keys are never committed.

## Which model does what

| Work | Model | Why |
|---|---|---|
| Read or write JOURNAL.md and README.md | Sonnet, medium effort: subagent `docs-writer` | Text to summarize or write: fast and cheap |
| Read the code to understand it or find where things are | Sonnet, medium effort: subagent `code-reader`, returns a summary with line numbers | Reading thousands of lines is expensive; a summary with line numbers is enough to know where to act |
| Modify the code | Opus 5.5, max effort (the main session) | The game is delicate (physics, rendering, phone); one mistake costs a version |
| Before modifying | The model that modifies re-reads the exact lines itself | A summary can be wrong; never modify from a summary alone |
| Publish / release the game | The main session has read the whole released file(s) | Nothing goes out without having been read |

The subagents are defined in `../.claude/agents/` (repository root) with `model` and `effort` in their frontmatter.
The main session's model and effort are set by the user (`/model`, `/effort max`).
