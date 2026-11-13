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
local DONE_COLOR = "|cff808080"
local COLOR_END = "|r"
local NEW_HINT = "/iv finder new starts a fresh checklist."

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
        id = "raid:" .. raid.instanceID,
        raid = raid.instanceID,
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
      id = "delve:" .. delve.name,
      delve = delve.name,
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

-- Checklist -----------------------------------------------------------------------

-- Freezes the picked suggestions so they stay listed (and get ticked) after
-- they are done, instead of dropping out of a recomputed plan.
function Finder.newChecklist(plan, budget, now)
  local items = {}
  for index, suggestion in ipairs(plan.picked) do
    items[index] = {
      id = suggestion.id, title = suggestion.title, minutes = suggestion.minutes,
      raid = suggestion.raid, delve = suggestion.delve,
    }
  end
  return { createdAt = now, budget = budget, used = plan.used, items = items }
end

-- progress: { locked = set of instanceIDs, delves = delve history, since }.
-- A raid is done once this character is locked to it; a delve once it was
-- finished after the checklist was made.
function Finder.isDone(item, progress)
  if item.raid then
    return progress.locked[item.raid] == true
  end
  local entry = item.delve and progress.delves[item.delve]
  return entry ~= nil and (entry.lastAt or 0) >= progress.since
end

-- Current suggestions that are not on the checklist, best first.
function Finder.otherSuggestions(plan, checklist)
  local listed = {}
  for _, item in ipairs(checklist.items) do
    listed[item.id] = true
  end
  local result = {}
  for _, group in ipairs({ plan.picked, plan.rest }) do
    for _, suggestion in ipairs(group) do
      if not listed[suggestion.id] then
        result[#result + 1] = suggestion
      end
    end
  end
  return result
end

-- No "~" before estimates: the game font draws it as a raised "˜".
local function suggestionLine(suggestion)
  return ("%s%d min  %s"):format(INDENT, suggestion.minutes, suggestion.title)
end

local function checklistLine(item, isDone)
  if isDone then
    return ("%s%s[x] %d min  %s%s"):format(INDENT, DONE_COLOR, item.minutes, item.title, COLOR_END)
  end
  return ("%s[ ] %d min  %s"):format(INDENT, item.minutes, item.title)
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

local function emptyPlanLine(others, budget)
  if #others == 0 then
    return INDENT .. "No suggestions right now."
  end
  return ("%sNothing fits in %d min. Try a longer session."):format(INDENT, budget)
end

local function appendChecklist(lines, checklist, progress, others)
  local doneCount = 0
  local itemLines = {}
  for index, item in ipairs(checklist.items) do
    local isDone = progress.isDone(item)
    doneCount = doneCount + (isDone and 1 or 0)
    itemLines[index] = checklistLine(item, isDone)
  end
  lines[#lines + 1] = ("Checklist for %d min: %d of %d done (about %d min planned)"):format(
    checklist.budget, doneCount, #checklist.items, checklist.used)
  if #checklist.items == 0 then
    lines[#lines + 1] = emptyPlanLine(others, checklist.budget)
  end
  for _, line in ipairs(itemLines) do
    lines[#lines + 1] = line
  end
  if #checklist.items > 0 and doneCount == #checklist.items then
    lines[#lines + 1] = INDENT .. "All done. Nice session!"
  end
end

-- progress.isDone(item) decides the ticks; others: Finder.otherSuggestions().
function Finder.lines(checklist, progress, others, achievements)
  local lines = {}
  appendChecklist(lines, checklist, progress, others)
  if #others > 0 then
    lines[#lines + 1] = "Also worth doing"
    for index = 1, math.min(#others, Finder.ALSO_LIMIT) do
      lines[#lines + 1] = suggestionLine(others[index])
    end
  end
  local close = almostFinished(achievements)
  if #close > 0 then
    lines[#lines + 1] = "Almost finished achievements"
    for index = 1, math.min(#close, Finder.ACHIEVEMENT_LIMIT) do
      lines[#lines + 1] = ns.Achievements.entryLine(close[index])
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = INDENT .. NEW_HINT
  return lines
end

ns.Finder = Finder
