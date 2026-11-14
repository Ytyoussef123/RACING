# Street Football 5v5

Street / neighborhood football for your phone: **5v5 (1 goalkeeper + 4 outfield players)**, quick **3–5 minute matches** on small "hood" courts: concrete, cages, walls, rooftops, beach and parking lots. It is about skills and style, and about building your own squad of fictional players. It is not a FIFA/eFootball copy.

- **Formations (flexible):** 2-1-1, 1-2-1, 1-1-2, 2-2, 1-1-1-1.
- **Positions:** GK, DEF, MID, WING, ATT.

## Status

**Phase 2 (core match), in test.** Branch `feature/core-match`, not yet tested on the phone. The start screen has two buttons, "Play — Concrete Cage" (walls on: the ball bounces off the boards) and "Play — Open Lot" (no walls: a ball leaving the court shows OUT and restarts), plus the language button. The match is a 3D low-poly court (30 x 18 m, small goals) with one controllable player and one ball. No teams or AI yet. See [JOURNAL.md](JOURNAL.md) for the phases and the log.

## How to play (controls)

Touch (phone):

- **Move:** floating joystick on the left part of the screen (it appears under your thumb).
- **SHOOT:** hold to charge (a power bar appears above the player), release to shoot. Turning while shooting curls the ball.
- **PASS:** tap for a ground pass in the joystick direction.
- **SPRINT:** hold.
- **MENU** (top-left) returns to the start screen.

Keyboard (PC):

- WASD or arrows: move
- Shift: sprint
- Space: shoot (hold to charge)
- E: pass

## Tech

- Godot 4.7.2, GDScript
- Compatibility renderer (OpenGL ES 3)
- Android first, landscape
- Languages: English and French

## Open in Godot

Godot Project Manager → **Import** → select `street-football/project.godot`.

## Build and install the APK

Full step-by-step guide: [docs/android-export.md](docs/android-export.md).

- **Way A, GitHub Actions artifact (recommended, nothing needed on your PC):** every push that changes `street-football/` builds a debug APK. Open the repository's **Actions** tab, open the latest run of "Street Football - Android debug APK", download the artifact zip, extract `street-football-debug.apk` and install it on your phone (allow "Install unknown apps" the first time).
- **Way B, export from Godot:** install Godot 4.7.2, export templates, JDK 17 and the Android SDK, set them in Editor Settings, then *Project → Export…* with the **Android** preset and install the APK on your phone.

## Folder structure

```
scenes/    .tscn files (boot, match, menus, court, player, ball, ui)
scripts/   core (autoloads), gameplay, physics, ai, data, ui
data/      config, players, courts, formations (JSON)
locale/    strings.csv (en, fr)
assets/    art, audio, fonts (free/original only)
tests/     headless physics tests (tests/physics_smoke_test.tscn, run by CI, excluded from the APK)
docs/      design notes, Android export guide
```

More detail and the project rules are in [CLAUDE.md](CLAUDE.md).

## Asset licenses

| Asset | Source | License |
|---|---|---|
| `icon.svg` | Original, made for this project | Same as the project |
| Default Godot font | Godot Engine | MIT (Godot Engine is MIT-licensed) |

All future assets must be free or original and listed in this table before they are committed.

## Content note

All players, teams and names are fictional. There are no real players, clubs, logos or licensed brands.
