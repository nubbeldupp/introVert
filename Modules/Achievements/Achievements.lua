-- Solo Achievement Hunter logic: progress, solo filter, display lines. Pure.
local _, ns = ...

local Achievements = {}

Achievements.ALMOST_DONE = 0.75
Achievements.LIST_LIMIT = 25

local INDENT = "  "
local NONE = INDENT .. "None right now."
local ROUNDING_GUARD = 1e-9

-- Top-level categories that are not solo content or no longer obtainable:
-- 95 = Player vs. Player, 81 = Feats of Strength, 15234 = Legacy.
local EXCLUDED_TOP_CATEGORIES = { [95] = true, [81] = true, [15234] = true }

function Achievements.isSoloCategory(topCategoryID)
  return not EXCLUDED_TOP_CATEGORIES[topCategoryID]
end

-- criteria: { { completed, quantity, required } }
-- A single counting criterion ("kill 100") uses its counter; otherwise the
-- share of completed criteria.
function Achievements.progress(criteria)
  local first = criteria[1]
  if #criteria == 1 and (first.required or 0) > 1 then
    local done = math.min(first.quantity or 0, first.required)
    return { done = done, total = first.required, fraction = done / first.required }
  end
  local done = 0
  for _, criterion in ipairs(criteria) do
    if criterion.completed then
      done = done + 1
    end
  end
  local total = math.max(#criteria, 1)
  return { done = done, total = #criteria, fraction = done / total }
end

local function byProgress(a, b)
  if a.fraction ~= b.fraction then
    return a.fraction > b.fraction
  end
  return a.name < b.name
end

local function entryLine(entry)
  local percent = math.floor(entry.fraction * 100 + ROUNDING_GUARD)
  local reward = entry.reward and (" - " .. entry.reward) or ""
  local group = entry.group and " [group]" or ""
  return ("%s%d%% %s (%d/%d)%s%s"):format(INDENT, percent, entry.name, entry.done, entry.total, reward, group)
end

local function section(entries, keep)
  local picked = {}
  for _, entry in ipairs(entries) do
    if keep(entry) then
      picked[#picked + 1] = entry
    end
  end
  table.sort(picked, byProgress)
  local lines = {}
  for index = 1, math.min(#picked, Achievements.LIST_LIMIT) do
    lines[index] = entryLine(picked[index])
  end
  if #lines == 0 then
    lines[1] = NONE
  end
  return lines
end

local function isAlmostDone(entry)
  return entry.fraction >= Achievements.ALMOST_DONE
end

local function hasRewardOnly(entry)
  return entry.reward ~= nil and not isAlmostDone(entry)
end

local function append(target, header, lines)
  target[#target + 1] = header
  for _, line in ipairs(lines) do
    target[#target + 1] = line
  end
end

-- entries: { { name, done, total, fraction, reward?, group? } }
function Achievements.lines(entries)
  local lines = {}
  append(lines, "Almost done (75%+)", section(entries, isAlmostDone))
  append(lines, "With rewards", section(entries, hasRewardOnly))
  return lines
end

ns.Achievements = Achievements
