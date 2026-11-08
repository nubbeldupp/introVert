-- Alts overview logic: vault summary, gold formatting, display lines. Pure;
-- durations reuse ns.RaidLockouts.formatDuration.
local _, ns = ...

local Alts = {}

local INDENT = "  "
local COPPER_PER_GOLD = 10000
local VAULT_SLOTS = 3

local function sortedKeys(map)
  local keys = {}
  for key in pairs(map or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

-- activities: C_WeeklyRewards.GetActivities(); types: { raid, dungeon, world }
-- mapping each row to its threshold type. Returns finished slots per row.
function Alts.vaultSummary(activities, types)
  local summary = { raid = 0, dungeon = 0, world = 0 }
  for _, activity in ipairs(activities or {}) do
    for row, rowType in pairs(types) do
      if activity.type == rowType and activity.progress >= activity.threshold then
        summary[row] = summary[row] + 1
      end
    end
  end
  return summary
end

function Alts.formatGold(copper)
  local gold = tostring(math.floor((copper or 0) / COPPER_PER_GOLD))
  local grouped = gold:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
  return grouped .. "g"
end

local function vaultLine(entry, lastReset)
  if (entry.updatedAt or 0) < lastReset then
    return INDENT .. "Vault: reset since last seen"
  end
  if not entry.vault then
    return INDENT .. "Vault: not available"
  end
  return ("%sVault: raid %d/%d, dungeons %d/%d, world %d/%d"):format(INDENT,
    entry.vault.raid, VAULT_SLOTS, entry.vault.dungeon, VAULT_SLOTS, entry.vault.world, VAULT_SLOTS)
end

local function seenText(name, entry, now, currentKey)
  if name == currentKey then
    return "online"
  end
  return ("seen %s ago"):format(ns.RaidLockouts.formatDuration(now - (entry.updatedAt or now)))
end

-- "90 Dwarf Rogue"; race and class are left out for entries recorded before
-- they were tracked.
local function describe(entry)
  local parts = { tostring(entry.level or 0) }
  if entry.race then
    parts[#parts + 1] = entry.race
  end
  if entry.class then
    parts[#parts + 1] = entry.class
  end
  return table.concat(parts, " ")
end

local function characterLines(name, entry, now, lastReset, currentKey)
  local lines = {
    ("%s (%s, ilvl %d) - %s"):format(name, describe(entry), entry.itemLevel or 0,
      seenText(name, entry, now, currentKey)),
    vaultLine(entry, lastReset),
  }
  if entry.hasRewards then
    lines[#lines + 1] = INDENT .. "Rewards waiting in the Great Vault"
  end
  lines[#lines + 1] = INDENT .. "Gold: " .. Alts.formatGold(entry.gold)
  return lines
end

-- alts: IntroVertDB.alts; lastReset: unix time of the last weekly reset.
function Alts.lines(alts, now, lastReset, currentKey)
  local names = sortedKeys(alts)
  if #names == 0 then
    return { "No characters recorded yet. Log in on each character once." }
  end
  local lines, totalCopper = {}, 0
  for _, name in ipairs(names) do
    for _, line in ipairs(characterLines(name, alts[name], now, lastReset, currentKey)) do
      lines[#lines + 1] = line
    end
    totalCopper = totalCopper + (alts[name].gold or 0)
  end
  lines[#lines + 1] = "Total gold: " .. Alts.formatGold(totalCopper)
  return lines
end

ns.Alts = Alts
