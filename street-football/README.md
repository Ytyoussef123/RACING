# Street Football 5v5

Street / neighborhood football for your phone: **5v5 (1 goalkeeper + 4 outfield players)**, quick **3–5 minute matches** on small "hood" courts: concrete, cages, walls, rooftops, beach and parking lots. It is about skills and style, and about building your own squad of fictional players. It is not a FIFA/eFootball copy.

- **Formations (flexible):** 2-1-1, 1-2-1, 1-1-2, 2-2, 1-1-1-1.
- **Positions:** GK, DEF, MID, WING, ATT.

## Status

**Phase 4 (player stats) is built** (branch `feature/player-stats`, created from `feature/five-v-five`). It waits for the phone test together with Phase 3 (5v5); nothing is merged into `main` yet. Phase 2 (core match) is done and tested on the phone. The match is a 3D low-poly court (36 x 22 m, small goals), 5v5 with AI opponents, a score and a 3:00 clock. See [JOURNAL.md](JOURNAL.md) for the phases and the log.

## Players and crews

- 30 fictional players (`data/players/*.json`) in 6 fictional street crews of 5 (`data/teams/*.json`): Concrete Kings (your crew for now), Rooftop Rebels, Harbor Hounds, Neon Nomads, Parking Lot Pirates, Sandstorm Strikers.
- Each player has a name, nationality, age, height, preferred foot, weak foot, positions, playstyle, skill-move stars, special skills, a look and 25 attributes (0-99).
- The attributes drive gameplay: speed, dribbling, passing, shooting, tackling, strength, stamina, goalkeeper skills and more. Players are placed in the formation slots where their overall rating is best.
- To add or edit players and crews (field names, attribute effects, ratings), see [docs/player-data.md](docs/player-data.md). No code change is needed.

## How to play

Start screen:

- **Formation:** cycles 2-1-1, 1-2-1, 1-1-2, 2-2, 1-1-1-1.
- **Difficulty:** Easy / Normal / Hard.
- **Play — Concrete Cage:** walls on, the ball bounces off the boards.
- **Play — Open Lot:** no walls. After the ball goes out: KICK-IN, CORNER or GOAL KICK for the team that did not touch it last.
- **Opponent:** cycles the 5 other crews. The away crew wears its alternate kit when the kits clash.
- Language button (English / French).

Match:

- Crew short names are shown next to the score. A name tag above your player shows "number  name  overall" with a stamina bar (green, orange, red). Sprinting drains stamina; when it is low, top speed drops.

- Your team is orange (keeper yellow) and attacks to the right. The AI team is cyan (keeper purple, formation 1-2-1).
- Top: score and 3:00 clock, court name under it. MENU (top-left) returns to the start screen. The formation button (top-right) changes your formation during the match.
- The team that conceded kicks off. At FULL TIME the score is shown, then the start screen returns after 4 s.
- Rules: one player controls the ball at a time. A tackle in reach has a chance to knock the ball loose; a miss slows the tackler briefly. A keeper holding the ball in his goal area can't be tackled. Players push each other apart.

Touch (phone):

- **Move:** floating joystick on the left part of the screen (it appears under your thumb).
Four buttons in a diamond (eFootball style). Labels and meaning switch with possession: the attack layout shows when your side holds the ball or touched the loose ball last (your pass or shot is travelling), the defense layout otherwise.

| Position | Attack | Defense | Key |
|---|---|---|---|
| Top-left | THROUGH | MATCH-UP | R |
| Top-right | SHOOT | TACKLE | Space |
| Bottom-left | PASS | SWITCH | E (SWITCH: Q) |
| Bottom-right | SPRINT | PRESS | Shift |

- **SHOOT:** hold to charge (a power bar appears above the player), release to shoot. Turning while shooting curls the ball.
- **PASS:** goes to the teammate closest to the joystick direction (it does not need to be exactly on the line).
- **THROUGH:** a pass into the space 4 m in front of the receiver, mostly toward the opponent goal and partly along his run, kept inside the court.
- **SPRINT:** hold.
- **PRESS** (hold SPRINT on defense): the player sprints goal-side of the ball carrier, then to the ball, and tackles by himself when in reach. On a loose ball he sprints to where he can meet it.
- **MATCH-UP** (hold): the player shadows the ball carrier goal-side at 1.6 m and follows his moves. No automatic tackle: tap TACKLE.
- **TACKLE:** tap when an opponent is in reach.
- **SWITCH:** jump to the teammate nearest the ball. Switching is also automatic when a pass leaves for a teammate, when a teammate gets the ball, and when defending if a teammate is clearly closer.
- **Receive assist:** the player a pass is aimed at runs to the earliest point of the ball's path he can reach and waits there. The joystick keeps aiming, so a first-time kick goes where you point (forward if the stick is neutral).
- **First-time kicks:** PASS, THROUGH or a shot pressed up to 0.5 s before the ball arrives is kept and played when the ball comes within reach.
- **Shoulder charge:** when your side does not have the ball, double-tap the joystick (F on keyboard) near the ball carrier to push him with the shoulder. Within 1.4 m you win or lose the duel (about 50 % at equal strength); too far, you only lunge and are slowed briefly.
- **Touch dribbling:** the player taps the ball ahead and catches it, further when sprinting (about 0.9 m running, 1.8 m sprinting). A ball knocked far ahead can be stolen, and is lost if it gets too far. Release the joystick to stop the ball at the feet. A pass or shot asked while the ball is ahead waits until the player reaches the ball.
- Goalkeepers are always AI.

Keyboard (PC):

- WASD or arrows: move
- R: through pass / match-up
- Space: shoot (hold to charge) / tackle
- E: pass / switch
- Shift: sprint / press
- Q: switch player (any time)
- F: shoulder charge

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
tests/     headless tests run by CI: physics_smoke_test, stats_test, match_sim_test (excluded from the APK)
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
