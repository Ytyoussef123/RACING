# Street Football 5v5

Street / neighborhood football for your phone: **5v5 (1 goalkeeper + 4 outfield players)**, quick **3–5 minute matches** on small "hood" courts: concrete, cages, walls, rooftops, beach and parking lots. It is about skills and style, and about building your own squad of fictional players. It is not a FIFA/eFootball copy.

- **Formations (flexible):** 2-1-1, 1-2-1, 1-1-2, 2-2, 1-1-1-1.
- **Positions:** GK, DEF, MID, WING, ATT.

## Status

**Phase 7 (progression) is built** (version 0.7.0, version code 7; branch `feature/progression`, created from `feature/polish`, Phase 6, which comes from `feature/menus`, Phase 5, then `feature/player-stats`, Phase 4, then `feature/five-v-five`, Phase 3). Phases 3 to 7 are waiting for the phone test; nothing is merged into `main` yet. Phase 2 (core match) is done and tested on the phone. The match is a 3D low-poly court (36 x 22 m, small goals), 5v5 with AI opponents, a score and a 3:00 clock. See [JOURNAL.md](JOURNAL.md) for the phases and the log.

## Players and crews

- 47 fictional players (`data/players/*.json`): 30 in 6 fictional street crews of 5 (`data/teams/*.json`) and 17 free agents (players in no crew: your 7 rookies and the 10 shop players). Crews: Concrete Kings, Rooftop Rebels, Harbor Hounds, Neon Nomads, Parking Lot Pirates, Sandstorm Strikers.
- Each player has a name, nationality, age, height, preferred foot, weak foot, positions, playstyle, skill-move stars, special skills, a look and 25 attributes (0-99).
- The attributes drive gameplay: speed, dribbling, passing, shooting, tackling, strength, stamina, goalkeeper skills and more. Players are placed in the formation slots where their overall rating is best.
- To add or edit players and crews (field names, attribute effects, ratings), see [docs/player-data.md](docs/player-data.md). No code change is needed.

## How to play

Main menu (`scenes/menus/main_menu.tscn`, the start scene): QUICK MATCH, MY CREW, SHOP, SETTINGS. Your coins are shown on it.

- **Quick match**, in 3 steps:
  1. Choose the crews: yours (My Crew by default; the 6 street crews are also available as exhibition teams) and the opponent (a street crew), changed with < and >. Team cards show kit colors, team rating and the 5 players; tap a player to open his card. The away crew wears its alternate kit when the kits clash.
  2. Formation: 2-1-1, 1-2-1, 1-1-2, 2-2 or 1-1-1-1, with a mini court showing your crew in place.
  3. Court and rules: Concrete Cage (walls, the ball bounces off the boards), Open Lot (no walls; after the ball goes out: KICK-IN, CORNER or GOAL KICK for the team that did not touch it last), or the unlocked Rooftop Cage and Beach Court (locked courts are greyed with their price), difficulty Easy / Normal / Hard, match length 3 / 4 / 5 minutes, then PLAY.
- **My crew:** your own squad (see Progression below). The player card shows name, overall, nationality, age, height, foot, positions, playstyle, weak foot, skill moves, special skills and all 25 attributes as colored bars (cyan 85+, green 75+, yellow 60+, red below).
- **Settings** (saved on the phone): language English / Français, show FPS, touch button size (small / normal / large), Sound on/off, Music on/off. Music plays in the menus, not in the match by default.
- **Results** after the final whistle: YOU WIN / DRAW / YOU LOSE, score, goals (time, crew, scorer, own goals marked) and match stats (shots, saves, passes completed, balls won, possession). REMATCH or MAIN MENU.
- **Android back button:** quits on the main menu, goes back on other screens, pauses or resumes in a match.

Match:

- Crew short names are shown next to the score. A name tag above your player shows "number  name  overall" with a stamina bar (green, orange, red). Sprinting drains stamina; when it is low, top speed drops.

- Your team is orange (keeper yellow) and attacks to the right. The AI team is cyan (keeper purple, formation 1-2-1).
- Top: score and clock, court name under it. PAUSE (top-left) opens the pause menu: RESUME, FORMATION (changes your formation) or QUIT MATCH.
- The team that conceded kicks off. At FULL TIME the results screen opens.
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
- **Skill moves:** with the ball, flick the joystick (quick swipe and release, under 0.22 s; C on keyboard). The direction compared to where the player faces picks the move:
  - Forward: knock-on (big touch to run onto), rainbow flick over a defender within 3 m, nutmeg through a defender within 1.6 m.
  - Side: elastico or step-over.
  - Back: heel-flick pass to a teammate behind, roulette or drag-back.
  - Each move needs a minimum of skill-move stars. Success chance = 0.45 + 0.1 per star + a dribbling bonus (max 0.97); a miss is a bad touch and the ball is lost. A good move can freeze defenders within 2.6 m. The move name pops up above the player.
  - Special skills: flip_flap, rainbow, nutmeg, roulette and heel_flick unlock their moves; first_time_shot makes one-touch shots more accurate; rabona removes the weak-foot penalty.
  - Numbers: `data/config/skills.json`; code: `scripts/gameplay/skill_moves.gd`.
- Goalkeepers are always AI. The AI also uses skill moves when a defender is within 2 m.

Keyboard (PC):

- WASD or arrows: move
- R: through pass / match-up
- Space: shoot (hold to charge) / tackle
- E: pass / switch
- Shift: sprint / press
- Q: switch player (any time)
- F: shoulder charge
- C: skill move

## Progression

- **My Crew:** your own squad, in the MY CREW screen. It starts with 7 new fictional rookies (overall 65-75, weaker than the street crews, which average about 80): 5 starters (with the keeper) and 2 on the bench. Tap two players to swap them; INFO opens the player card; the LV button upgrades a player with coins. A warning shows if no keeper starts. Coins and your match record are shown.
- **Coins:** earned after every match: win 150, draw 80, loss 50, plus 15 per goal scored, times 0.8 on Easy, 1.0 on Normal, 1.4 on Hard (`data/config/progression.json`). The results screen shows "+N coins (total M)". You start with 500.
- **Shop (SHOP):** 10 free agents (overall 74-89) priced 400 + 60 per overall point above 70 (640 to 1540); signed players join the bench. Two courts to unlock: Rooftop Cage (32 x 20 m, walls, neon; 600 coins) and Beach Court (34 x 20 m, no walls, sand: the ball rolls slower and bounces less; 900 coins).
- **Upgrades:** levels 1 to 5, costing 250, 450, 700 and 1000 coins; each level adds 2 to every attribute, so it really changes play.
- **Save on the phone:** `user://savegame.json` (coins, signed players and levels, My Crew, formation, unlocked courts, match record). It is written through a temporary file; a damaged save is kept as `savegame.bad.json` and a new save starts. Settings are in `user://settings.cfg`.
- Street crews are never sold, so you never meet your own players in the other team.

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
- The CI also renders every screen at 2400x1080 (virtual display) and prints the screenshots in the log; `.github/scripts/decode_screenshots.py` turns them back into images.
- **Way B, export from Godot:** install Godot 4.7.2, export templates, JDK 17 and the Android SDK, set them in Editor Settings, then *Project → Export…* with the **Android** preset and install the APK on your phone.

## Folder structure

```
scenes/    .tscn files (boot, match, menus, court, player, ball, ui)
scripts/   core (autoloads), gameplay, physics, ai, data, ui
data/      config, players, courts, formations (JSON)
locale/    strings.csv (en, fr)
assets/    art, audio, fonts (free/original only)
tools/     helper scripts, e.g. generate_audio.py (Python + numpy) that generates assets/audio/*.wav
tests/     run by CI, excluded from the APK: physics_smoke_test, stats_test, progression_test, ui_flow_test, match_sim_test (headless) and screenshot_tour (rendered screenshots)
docs/      design notes, Android export guide
```

More detail and the project rules are in [CLAUDE.md](CLAUDE.md).

## Asset licenses

| Asset | Source | License |
|---|---|---|
| `icon.svg` | Original, made for this project | Same as the project |
| Default Godot font | Godot Engine | MIT (Godot Engine is MIT-licensed) |
| `assets/audio/*.wav` | Generated by `tools/generate_audio.py` (original, no samples) | Same as the project (original work) |

All future assets must be free or original and listed in this table before they are committed.

## Content note

All players, teams and names are fictional. There are no real players, clubs, logos or licensed brands.
