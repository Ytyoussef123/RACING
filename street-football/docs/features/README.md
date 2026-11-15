# Feature files

One file per feature. Each one says what the feature does **now**, where it lives (code, numbers,
tests), every change made to it (newest first, with the date, the reason and the branch), what must
not be undone, and how to check it after a change.

**Before changing a feature:** read its file here first (current state, history, "Do not undo").
**After changing it:** add a line at the top of its History, update "What it does now", "Last change"
and, if needed, "Do not undo". A change that touches several features is written in each of them.

`JOURNAL.md` stays the dated log of the whole project; these files are the same history sorted by
feature, so the last change to one feature is found in one place.

| Feature | File |
|---|---|
| Ball physics, courts, walls, goals | [ball-physics.md](ball-physics.md) |
| Player movement, speed, stamina, collisions | [player-movement.md](player-movement.md) |
| Dribbling (touches, turns, ball at the feet, steals) | [dribbling.md](dribbling.md) |
| Passing, through passes, receiving | [passing-and-receiving.md](passing-and-receiving.md) |
| Shooting | [shooting.md](shooting.md) |
| Defending: press, match-up, tackle, shoulder charge | [defending.md](defending.md) |
| Skill moves | [skill-moves.md](skill-moves.md) |
| AI (team brain, ball carrier, support, keeper, difficulty) | [ai.md](ai.md) |
| Team movement (jobs off the ball, support, runs in behind, give-and-go, cover, marking, spacing) | [team-movement.md](team-movement.md) |
| Player stats, ratings, positions, players and crews | [player-stats.md](player-stats.md) |
| Match flow: kick-off, goals, restarts, clock, results, formations | [match-flow.md](match-flow.md) |
| Player body and animation | [player-body-and-animation.md](player-body-and-animation.md) |
| Camera | [camera.md](camera.md) |
| Touch controls and match HUD | [touch-controls-and-hud.md](touch-controls-and-hud.md) |
| Menus, settings, translations | [menus-and-settings.md](menus-and-settings.md) |
| Progression and save (coins, shop, upgrades, unlocks) | [progression-and-save.md](progression-and-save.md) |
| Audio and visual effects | [audio-and-effects.md](audio-and-effects.md) |
| Tests and CI (screenshots, motion study, balance, APK) | [testing-and-ci.md](testing-and-ci.md) |

Android export and signing: [../android-export.md](../android-export.md). Early design choices:
[../design-decisions.md](../design-decisions.md). Player and crew data format: [../player-data.md](../player-data.md).

## Template

```markdown
# <Feature>

Last change: YYYY-MM-DD, <what> (branch `feature/...`, commit `abc1234`)

## What it does now
- Short bullets: the behavior as it is today.

## Where it lives
- Code: `path/file.gd` (ClassName): what it does, main functions.
- Numbers: `data/config/<file>.json` -> keys.
- Tests: `tests/<file>.gd`: which checks.

## History (newest first)
- YYYY-MM-DD: what changed. Why (user feedback, bug, balance). Branch `feature/...`, commits `abc1234`.

## Do not undo
- Decisions and lessons that must stay (and why), e.g. a bug that came back once.

## How to check after a change
- The tests, screenshots or log lines to look at.
```
