-- Delve Companion logic: tier parsing, run history, display lines. Pure.
local _, ns = ...

local Delves = {}

local INDENT = "  "

local function sortedKeys(map)
  local keys = {}
  for key in pairs(map or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

-- "Tier 8" / "Stufe 8" -> 8; nil when the name holds no number (e.g. Story).
function Delves.parseTier(difficultyName)
  local digits = tostring(difficultyName or ""):match("%d+")
  return digits and tonumber(digits)
end

-- Returns a new history with one more run of `name`; keeps the best tier.
function Delves.record(history, name, tier, now)
  local result = {}
  for key, value in pairs(history or {}) do
    result[key] = value
  end
  local previous = result[name] or { runs = 0, bestTier = 0 }
  result[name] = {
    runs = previous.runs + 1,
    bestTier = math.max(previous.bestTier or 0, tier or 0),
    lastAt = now,
  }
  return result
end

local function byIndex(a, b)
  return a.index < b.index
end

local function slotLine(activity)
  if activity.progress >= activity.threshold then
    local level = (activity.level or 0) > 0 and (", level " .. activity.level) or ""
    return ("%sSlot %d: done (%d/%d)%s"):format(INDENT, activity.index, activity.threshold, activity.threshold, level)
  end
  return ("%sSlot %d: %d/%d, %d more"):format(
    INDENT, activity.index, activity.progress, activity.threshold, activity.threshold - activity.progress)
end

-- activities: C_WeeklyRewards.GetActivities results for the world row.
function Delves.vaultLines(activities)
  if not activities or #activities == 0 then
    return { INDENT .. "No vault data yet." }
  end
  local sorted = {}
  for index, activity in ipairs(activities) do
    sorted[index] = activity
  end
  table.sort(sorted, byIndex)
  local lines = {}
  for _, activity in ipairs(sorted) do
    lines[#lines + 1] = slotLine(activity)
  end
  return lines
end

-- delves: { { name, zone } }
function Delves.bountifulLines(delves)
  if not delves or #delves == 0 then
    return { INDENT .. "None found right now." }
  end
  local lines = {}
  for _, delve in ipairs(delves) do
    lines[#lines + 1] = ("%s%s (%s)"):format(INDENT, delve.name, delve.zone)
  end
  table.sort(lines)
  return lines
end

function Delves.historyLines(history)
  local names = sortedKeys(history)
  if #names == 0 then
    return { INDENT .. "No delves recorded yet. Finish a delve to start." }
  end
  local lines = {}
  for _, name in ipairs(names) do
    local entry = history[name]
    local tier = (entry.bestTier or 0) > 0 and tostring(entry.bestTier) or "?"
    local unit = entry.runs == 1 and "run" or "runs"
    lines[#lines + 1] = ("%s%s - best tier %s, %d %s"):format(INDENT, name, tier, entry.runs, unit)
  end
  return lines
end

local function append(target, header, section)
  target[#target + 1] = header
  for _, line in ipairs(section) do
    target[#target + 1] = line
  end
end

function Delves.lines(vaultSection, bountifulSection, historySection)
  local lines = {}
  append(lines, "This week (Great Vault, world activities)", vaultSection)
  append(lines, "Bountiful delves today", bountifulSection)
  append(lines, "Your delves", historySection)
  return lines
end

ns.Delves = Delves
