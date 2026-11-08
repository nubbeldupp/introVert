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

## Install

Copy (or symlink) this folder to
`World of Warcraft/_retail_/Interface/AddOns/IntroVert`.

If the client shows the addon as out of date, check your build with
`/dump (select(4, GetBuildInfo()))` and add it to `## Interface` in `IntroVert.toc`.

## Development

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
