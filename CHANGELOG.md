# Changelog

All notable changes to introVert are listed here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [Semantic Versioning](https://semver.org/).

## [0.11.0] - 2026-11-14

### Added
- Drop luck in the Mounts tab: once a mount has attempts, a line like "1% drop: 33% of players would have it after 40 attempts"
- The attempt message in chat shows the same: "Attempt 12 for Invincible (1% drop: 11% of players would have it by now)."
- Drop chances from the Rarity addon's database: 1% for most mounts; Raven Lord 1 in 67, Blue Proto-Drake 1 in 77, Spawn of Horridon 1 in 66, Clutch of Ji-Kun 1 in 50 (`dropChance` in `MountData.lua`)
- The Obsidian Sanctum drakes are guaranteed with 3 drakes up and show no luck line

## [0.10.0] - 2026-11-14

### Added
- Away reply: while you are AFK, everyone who whispers (character or Battle.net) can get one friendly reply per away period; off by default, replies editable in the options
- Coming back from AFK prints who whispered: "While you were away (20m): 2 whispers from Anna, Friend."
- Game Masters and recruitment spam get no away reply

### Fixed
- Greetings, goodbyes and replies are now separated with `;` in the edit box, so a single message can contain a comma ("Thanks, but I play solo!" was split in two). Keywords still use commas
- Modules now start in a fixed order, so journal entries for the same event (boss kill and mount attempt) always appear in the same order

## [0.9.0] - 2026-11-14

### Added
- Session Journal: new Journal tab (`/iv journal`) showing what you did this session and in earlier ones
- Logs raid and dungeon boss kills, delves, Labyrinth chambers, newly earned achievements, mount attempts and the gold you made or spent
- A login starts a new session, a `/reload` continues it; the last 30 sessions are kept
- One chat line on login sums up your last session ("Last session: 2 boss kills, 1 delve, +1,234g."); can be switched off in the options

### Changed
- The window is wider so seven tabs fit

## [0.8.0] - 2026-11-13

### Added
- Dungeon mounts in the Mounts tab, in their own section: Deathcharger (Stratholme), Raven Lord (Sethekk Halls, heroic), Blue Proto-Drake (Utgarde Pinnacle, heroic), Drake of the North Wind (Vortex Pinnacle), Vitreous Stone Drake (Stonecore), Armored Razzashi Raptor and Swift Zulian Panther (Zul'Gurub)
- Dungeon boss kills count as mount attempts, like raids; `/iv mounts set` and `/iv mounts check` cover dungeon mounts too

### Changed
- The Mounts tab is split into "Raid mounts" and "Dungeon mounts"; dungeons show "no lockout, farm any time" instead of a per-character status
- The total reads "Collected X of Y tracked mounts"

## [0.7.0] - 2026-11-13

### Added
- Finder checklist: the session plan is saved per character and ticks itself off; a raid once this character is saved to it, a bountiful delve once it is finished
- Done items stay on the list, greyed out with [x]; "All done. Nice session!" when everything is ticked
- `/iv finder new` plans a fresh checklist from what is still open; `/iv finder <minutes>` also starts a new one
- The checklist survives `/reload`; logging in starts a new session

### Changed
- "Also worth doing" stays live and leaves out what is already on the checklist

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

[0.11.0]: https://github.com/nubbeldupp/introVert/releases/tag/v0.11.0
[0.10.0]: https://github.com/nubbeldupp/introVert/releases/tag/v0.10.0
[0.9.0]: https://github.com/nubbeldupp/introVert/releases/tag/v0.9.0
[0.8.0]: https://github.com/nubbeldupp/introVert/releases/tag/v0.8.0
[0.7.0]: https://github.com/nubbeldupp/introVert/releases/tag/v0.7.0
[0.6.0]: https://github.com/nubbeldupp/introVert/releases/tag/v0.6.0
[0.5.0]: https://github.com/nubbeldupp/introVert/releases/tag/v0.5.0
