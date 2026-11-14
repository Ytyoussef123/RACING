# Street Football 5v5

Street / neighborhood football for your phone: **5v5 (1 goalkeeper + 4 outfield players)**, quick **3–5 minute matches** on small "hood" courts: concrete, cages, walls, rooftops, beach and parking lots. It is about skills and style, and about building your own squad of fictional players. It is not a FIFA/eFootball copy.

- **Formations (flexible):** 2-1-1, 1-2-1, 1-1-2, 2-2, 1-1-1-1.
- **Positions:** GK, DEF, MID, WING, ATT.

## Status

**Phase 1 (setup).** There is a test screen only (tap counter, EN/FR switch, FPS counter, device info). No gameplay yet. See [JOURNAL.md](JOURNAL.md) for the phases and the log.

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
