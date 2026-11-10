# Changelog

All notable changes to introVert are listed here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [Semantic Versioning](https://semver.org/).

## [0.6.0] - 2026-11-10

### Changed
- Mounts tab redesigned for readability: one row per missing mount with a short status line, e.g. "Karazhan: free on all 5 characters" or "free on 3 of 5 characters"
- Click a mount to open or close its character list, with reset times for locked characters
- Character names in class colours; the realm is hidden for characters on your current realm
- Alts now also store the class token, so colours work in any client language

## [0.5.0] - 2026-11-09

First public release.

### Development steps
1. Quiet Groups: LFD/LFR chat filter, greet and farewell, Leave button, ready alarm, encounter mute
2. Options panel under Options → AddOns
3. Raid Farm Planner, part 1: lockouts across characters
4. Raid Farm Planner, part 2: missing raid mounts and attempts
5. introVert window with Raids and Mounts tabs
6. Delve Companion tab
7. Solo Achievement Hunter tab
8. Solo Content Finder, `/iv mounts set` and GitHub CI (busted on Lua 5.1 and 5.4)
9. Fix: delve tier read from the scenario header widget
10. Labyrinth of Kindo'jan tracked by chambers
11. Do Not Disturb, Alts tab and minimap button
12. Release prep: MIT license, changelog, version 0.5.0

### Quiet Groups
- Chat filter for random dungeons and LFR, set per profile: all, keywords only, leader only, or off
- Optional greeting when joining and farewell when the run ends
- Leave button after the final boss
- Ready alarm, even while the game is in the background
- Encounter focus: group chat muted during boss fights and briefly after a wipe
- `/iv quiet log` shows what was hidden this session

### Do Not Disturb
- Auto-declines guild invites, duels, pet battle duels and group invites (friends still get through)
- Recruitment spam filter for channels, whispers, say and yell (English and German)
- Optional polite whisper reply with editable phrases
- `/iv dnd` and `/iv dnd log` show what was blocked

### Raid Farm Planner
- Raid lockouts across all your characters, `/iv raids <name>` for one raid
- Missing raid mounts with boss, difficulty and attempt counter
- Shows which characters are still free to try for each mount
- `/iv mounts set <mount> <count>` to enter attempts from before introVert

### Delve Companion
- Great Vault world progress
- Today's bountiful delves
- Delve history with tiers
- Labyrinth of Kindo'jan: chambers per visit and best tier

### Solo Achievement Hunter
- Achievements you can finish alone, closest to completion first
- PvP, Feats of Strength and Legacy skipped; group content tagged

### Solo Content Finder
- `/iv finder [minutes]` plans the best-value solo activities for the time you have

### Alts
- Level, race, class, item level, Great Vault, rewards waiting and gold for every character
- Total gold across the account

### General
- introVert window with tabs (`/iv window`)
- Options panel under Options → AddOns → introVert
- Minimap button (left-click: window, right-click: options) and Addon Compartment entry
- `/iv help` lists all commands

[0.6.0]: https://github.com/nubbeldupp/introVert/releases/tag/v0.6.0
[0.5.0]: https://github.com/nubbeldupp/introVert/releases/tag/v0.5.0
