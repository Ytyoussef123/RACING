# CLAUDE.md (repository root)

This repository holds two separate games:

- **Corniche Rush** (driving game, Three.js): `game/`, `src/`, `tests/`, `tools/`, `versions/`, with the root `README.md` and `JOURNAL.md` (in French).
- **Street Football 5v5** (Godot 4.7.2, Android): everything in `street-football/`. Its rules are in `street-football/CLAUDE.md`. Read that file before working on it.

Never mix the two: a change to one game must not touch the other's files.
The subagents in `.claude/agents/` (`docs-writer`, `code-reader`) are for Street Football.
