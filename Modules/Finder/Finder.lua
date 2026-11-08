-- Solo Content Finder logic: turns raid, delve and achievement data into a
-- time-boxed session plan. Pure; achievement lines reuse ns.Achievements.
local _, ns = ...

local Finder = {}

Finder.MOUNT_VALUE = 3
Finder.DEFAULT_RAID_MINUTES = 20
Finder.DELVE_MINUTES = 15
Finder.VAULT_DELVE_VALUE = 5
Finder.DELVE_VALUE = 3
Finder.ALSO_LIMIT = 5
Finder.ALMOST_FINISHED = 0.9
Finder.ACHIEVEMENT_LIMIT = 5

local INDENT = "  "

-- raids: Mounts.resolve().raids; lockedInstances: set of instanceIDs this
-- character is locked to this week.
function Finder.mountSuggestions(raids, lockedInstances)
  local locked = lockedInstances or {}
  local result = {}
  for _, raid in ipairs(raids or {}) do
    if not locked[raid.instanceID] then
      local names = {}
      for index, mount in ipairs(raid.missing) do
        names[index] = mount.note and ("%s (%s)"):format(mount.mountName, mount.note) or mount.mountName
      end
      result[#result + 1] = {
        title = raid.name .. ": " .. table.concat(names, ", "),
        minutes = raid.minutes or Finder.DEFAULT_RAID_MINUTES,
        value = Finder.MOUNT_VALUE * #raid.missing,
      }
    end
  end
  return result
end

function Finder.vaultOpen(activities)
  for _, activity in ipairs(activities or {}) do
    if activity.progress < activity.threshold then
      return true
    end
  end
  return false
end

function Finder.delveSuggestions(bountiful, vaultOpen)
  local suffix = vaultOpen and " (vault)" or ""
  local result = {}
  for _, delve in ipairs(bountiful or {}) do
    result[#result + 1] = {
      title = ("Bountiful delve: %s (%s)%s"):format(delve.name, delve.zone, suffix),
      minutes = Finder.DELVE_MINUTES,
      value = vaultOpen and Finder.VAULT_DELVE_VALUE or Finder.DELVE_VALUE,
    }
  end
  return result
end

local function rate(suggestion)
  return suggestion.value / suggestion.minutes
end

local function byRate(a, b)
  if rate(a) ~= rate(b) then
    return rate(a) > rate(b)
  end
  return a.title < b.title
end

-- Greedy: best value per minute first, anything that fits the budget.
function Finder.plan(suggestions, budget)
  local sorted = {}
  for index, suggestion in ipairs(suggestions) do
    sorted[index] = suggestion
  end
  table.sort(sorted, byRate)
  local result = { picked = {}, rest = {}, used = 0 }
  for _, suggestion in ipairs(sorted) do
    if result.used + suggestion.minutes <= budget then
      result.picked[#result.picked + 1] = suggestion
      result.used = result.used + suggestion.minutes
    else
      result.rest[#result.rest + 1] = suggestion
    end
  end
  return result
end

-- No "~" before estimates: the game font draws it as a raised "˜".
local function suggestionLine(suggestion)
  return ("%s%d min  %s"):format(INDENT, suggestion.minutes, suggestion.title)
end

local function byFraction(a, b)
  if a.fraction ~= b.fraction then
    return a.fraction > b.fraction
  end
  return a.name < b.name
end

local function almostFinished(achievements)
  local close = {}
  for _, entry in ipairs(achievements or {}) do
    if entry.fraction >= Finder.ALMOST_FINISHED then
      close[#close + 1] = entry
    end
  end
  table.sort(close, byFraction)
  return close
end

local function emptyPlanLine(plan, budget)
  if #plan.rest == 0 then
    return INDENT .. "No suggestions right now."
  end
  return ("%sNothing fits in %d min. Try a longer session."):format(INDENT, budget)
end

function Finder.lines(plan, budget, achievements)
  local lines = { ("Plan for %d min (about %d min planned)"):format(budget, plan.used) }
  if #plan.picked == 0 then
    lines[#lines + 1] = emptyPlanLine(plan, budget)
  end
  for _, suggestion in ipairs(plan.picked) do
    lines[#lines + 1] = suggestionLine(suggestion)
  end
  if #plan.rest > 0 then
    lines[#lines + 1] = "Also worth doing"
    for index = 1, math.min(#plan.rest, Finder.ALSO_LIMIT) do
      lines[#lines + 1] = suggestionLine(plan.rest[index])
    end
  end
  local close = almostFinished(achievements)
  if #close > 0 then
    lines[#lines + 1] = "Almost finished achievements"
    for index = 1, math.min(#close, Finder.ACHIEVEMENT_LIMIT) do
      lines[#lines + 1] = ns.Achievements.entryLine(close[index])
    end
  end
  return lines
end

ns.Finder = Finder
