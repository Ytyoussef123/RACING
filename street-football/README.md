# Street Football 5v5

Street / neighborhood football for your phone: **5v5 (1 goalkeeper + 4 outfield players)**, quick **3–5 minute matches** on small "hood" courts: concrete, cages, walls, rooftops, beach and parking lots. It is about skills and style, and about building your own squad of fictional players. It is not a FIFA/eFootball copy.

- **Formations (flexible):** 2-1-1, 1-2-1, 1-1-2, 2-2, 1-1-1-1.
- **Positions:** GK, DEF, MID, WING, ATT.

## Status

**Phase 3 (5v5) is in test** (branch `feature/five-v-five`). CI is green (physics tests and a headless AI-vs-AI match), but it is not tested on the phone yet. Phase 2 (core match) is done and tested on the phone. The match is a 3D low-poly court (30 x 18 m, small goals), 5v5 with AI opponents, a score and a 3:00 clock. See [JOURNAL.md](JOURNAL.md) for the phases and the log.

## How to play

Start screen:

- **Formation:** cycles 2-1-1, 1-2-1, 1-1-2, 2-2, 1-1-1-1.
- **Difficulty:** Easy / Normal / Hard.
- **Play — Concrete Cage:** walls on, the ball bounces off the boards.
- **Play — Open Lot:** no walls. After the ball goes out: KICK-IN, CORNER or GOAL KICK for the team that did not touch it last.
- Language button (English / French).

Match:

- Your team is orange (keeper yellow) and attacks to the right. The AI team is cyan (keeper purple, formation 1-2-1).
- Top: score and 3:00 clock, court name under it. MENU (top-left) returns to the start screen. The formation button (top-right) changes your formation during the match.
- The team that conceded kicks off. At FULL TIME the score is shown, then the start screen returns after 4 s.
- Rules: one player controls the ball at a time. A tackle in reach has a chance to knock the ball loose; a miss slows the tackler briefly. A keeper holding the ball in his goal area can't be tackled. Players push each other apart.

Touch (phone):

- **Move:** floating joystick on the left part of the screen (it appears under your thumb).
- **SHOOT:** hold to charge (a power bar appears above the player), release to shoot. Turning while shooting curls the ball.
- **PASS:** goes to the best teammate in the joystick direction. Becomes **TACKLE** when an opponent has the ball.
- **SPRINT:** hold.
- **SWITCH:** jump to the teammate nearest the ball. Switching is also automatic when a pass leaves for a teammate, when a teammate gets the ball, and when defending if a teammate is clearly closer.
- Goalkeepers are always AI.

Keyboard (PC):

- WASD or arrows: move
- Shift: sprint
- Space: shoot (hold to charge)
- E: pass / tackle
- Q: switch player

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
tests/     headless tests run by CI, excluded from the APK (tests/physics_smoke_test.tscn, tests/match_sim_test.tscn: 150 s AI-vs-AI match)
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
