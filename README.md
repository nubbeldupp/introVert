# introVert

World of Warcraft (Retail) addon for players who prefer to play alone.

## Modules

### Quiet Groups (v0.1)

Turns on automatically in matchmade dungeons (LFD) and Raid Finder (LFR),
off in premades, follower dungeons and the open world.

- **Chat filter** for party / instance / raid chat. Levels per profile:
  - `off` – show everything
  - `keywords` – only lines with your name, your role word (tank/heal), or a keyword (`wait`, `afk`, `kick`, `brb`)
  - `leader` – only the group leader
  - `all` – hide everything
  Raid warnings are never filtered. Your own lines always show.
- **Encounter focus**: mutes all group chat during boss fights and for 30 s after a wipe.
- **Greeting / farewell**: one short line when the group forms, one when it completes, then a **Leave group** button.
- **Loud alarm** (Master channel + taskbar flash) for ready checks, role checks and queue pops.
- **Hidden log**: read what was filtered with `/iv quiet log` (session only, never saved).

### Do Not Disturb

Declines automatically (each switchable in Options → AddOns → introVert):
guild invites, duels, pet battle duels and group invites from strangers
(friends and Battle.net friends still get through). The popup closes and you
get one short chat line. Optional polite whisper reply, off by default.

**Recruitment spam filter**: hides guild recruitment in General, Trade,
Services, say/yell and whispers, in English and German ("recruit",
"rekrut", or guild/Gilde together with join, members, sucht, Mitglieder, ...).

```
/iv dnd             what was declined and hidden this session
/iv dnd log         the last 20 entries
/iv dnd on|off      all shields at once
```

### Minimap button

A round introVert button on the minimap edge (no extra library): **drag** it
along the edge to move it, **left-click** opens or closes the window,
**right-click** opens the options. Hide or show it with `/iv minimap` or the
"Show minimap button" switch in the options. introVert is also listed in the
game's own addon menu on the minimap when that menu is visible.

### Alts tab

`/iv alts` lists every character you logged in on: level, item level, gold,
Great Vault (finished slots per row: raid, dungeons, world), unclaimed vault
rewards and when you last saw them, plus total gold. A vault recorded before
the last weekly reset shows "reset since last seen". `/iv raids forget
Name-Realm` removes a character here too.

### Window

`/iv window` opens the introVert window: movable (drag it), closes with
Escape, one tab per module (Raids, Mounts). It updates live while open,
e.g. when a mount attempt is counted. `/iv raids` and `/iv mounts` open it
on their tab; quick answers (`/iv raids <name>`, `/iv mounts check`) stay
in chat.

### Raid lockouts (Raid Farm Planner, part 1)

Records every character's raid lockouts (account-wide) each time you log in
or kill a raid boss. Lockouts that have reset disappear automatically.

```
/iv raids                       all characters and their active lockouts
/iv raids <name>                who is locked / free for one raid (e.g. /iv raids ulduar)
/iv raids forget <Name-Realm>   remove a deleted character
```

Log in once on each alt so it gets recorded.

### Raid mounts (Raid Farm Planner, part 2)

Tracks mount drops from 15 legacy raids (Karazhan to Antorus). Mount names
and "collected" come from your mount journal; the addon only stores item IDs.

```
/iv mounts          missing mounts per raid, attempts, and which alts are free
/iv mounts check    list item IDs the game does not recognise as mounts
/iv mounts set invincible 12    enter attempts from before you had introVert
```

- An attempt is counted when you kill the dropping boss on an eligible
  difficulty while the mount is still uncollected ("Attempt 12 for Invincible.").
- Boss matching uses English encounter names, so attempt counting needs an
  English client. The missing-mounts list works in any language.
- The data in `Modules/Raids/MountData.lua` is unverified for 12.1; run
  `/iv mounts check` once and report anything it lists.

### Delve Companion

`/iv delves` opens the **Delves** tab:

- **This week**: Great Vault world-activity row, per slot done or "N more".
- **Bountiful delves today**: found from every zone's delve markers.
- **Your delves**: each finished delve is recorded (account-wide) with best
  tier and run count; you get one line in chat ("Delve recorded: ...").

The tier comes from the delve header widget of the scenario tracker.
**The Labyrinth of Kindo'jan** reports every chamber as finished, so it is
tracked by chambers instead of runs: "best tier 8, 14 chambers, best visit 9/9".

Each section reads the game API defensively: if an API changed, that section
shows "Not available on this client" instead of breaking the window.

### Solo Achievement Hunter

`/iv achievements` (or `/iv ach`) opens the **Achievements** tab:

- **Almost done (75%+)**: closest first, up to 25.
- **With rewards**: unfinished achievements that give a title, mount, pet, …

Leaves out PvP, Feats of Strength, Legacy, guild and completed achievements.
Dungeons & Raids stay in (old raids are soloable) but are tagged `[group]`.
The scan runs when the tab opens and is cached until your progress changes.

### Solo Content Finder

`/iv finder [minutes]` (or `/iv solo`) opens the **Finder** tab with a plan
for a solo session of that length (default 60, also a slider in options):

- raids where **this character** is free and you are missing mounts
  (rough clear times per raid in `MountData.lua`, tune as you like)
- today's bountiful delves, ranked higher while your Great Vault world row
  is not full
- picked by value per minute until the time budget is full; the rest is
  listed under "Also worth doing"
- achievements at 90%+ listed separately (no time estimate possible)

### Settings

All settings are in **Options → AddOns → introVert** (or type `/iv options`):
toggles per profile, chat level dropdowns, boss-fight and wipe muting,
greet / goodbye / alarm switches, and **Edit** buttons for the keyword,
greeting and goodbye lists (comma separated). The panel and the slash
commands share the same saved settings.

### Commands

```
/iv help                  list all commands (also: /iv)
/iv options               open the settings panel (also: /iv config)
/iv quiet                 status
/iv quiet on|off          enable/disable both profiles
/iv quiet dungeon <level> set dungeon chat level
/iv quiet lfr <level>     set LFR chat level
/iv quiet log             show the last 20 hidden lines
```

Ideas for later live in [docs/IDEAS.md](docs/IDEAS.md).

## Install

Copy (or symlink) this folder to
`World of Warcraft/_retail_/Interface/AddOns/IntroVert`.

If the client shows the addon as out of date, check your build with
`/dump (select(4, GetBuildInfo()))` and add it to `## Interface` in `IntroVert.toc`.

## Development

Every push runs the full test suite on GitHub Actions with Lua 5.1 (the WoW
client's version) and Lua 5.4 (`.github/workflows/tests.yml`).

Requires Lua + [busted](https://lunarmodules.github.io/busted/) (+ luacov for coverage):

```bash
brew install lua luarocks
luarocks install --local busted
luarocks install --local luacov
```

Run from the project root:

```bash
~/.luarocks/bin/busted
~/.luarocks/bin/busted --coverage && ~/.luarocks/bin/luacov && tail -20 luacov.report.out
```

Pure logic lives in `Profile.lua`, `Filter.lua`, `Phrases.lua`, `Commands.lua`
and `Core/Defaults.lua`; `tests/support/wow.lua` fakes the WoW API for the
event-driven parts.
