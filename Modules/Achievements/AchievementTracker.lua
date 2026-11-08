-- Solo Achievement Hunter: scans achievements when the Achievements tab is
-- shown and caches the result until progress changes.
local _, ns = ...

local Achievements = ns.Achievements

local TOP_LEVEL = -1
local MAX_CATEGORY_DEPTH = 10
local DUNGEONS_AND_RAIDS = 168
local UNAVAILABLE = { "  Not available on this client." }
local HELP_LINES = { "/iv achievements - almost-done and rewarding solo achievements (also /iv ach)" }

local Tracker = {}
local cachedLines
local dirty = true

local function topCategory(categoryID)
  local current = categoryID
  for _ = 1, MAX_CATEGORY_DEPTH do
    local _, parentID = GetCategoryInfo(current)
    if not parentID or parentID == TOP_LEVEL then
      return current
    end
    current = parentID
  end
  return current
end

local function readCriteria(achievementID)
  local criteria = {}
  for index = 1, GetAchievementNumCriteria(achievementID) do
    local _, _, completed, quantity, required = GetAchievementCriteriaInfo(achievementID, index)
    criteria[index] = { completed = completed, quantity = quantity, required = required }
  end
  return criteria
end

local function readAchievement(categoryID, index, top)
  local id, name, _, completed, _, _, _, _, _, _, rewardText, isGuild, _, _, isStatistic =
    GetAchievementInfo(categoryID, index)
  if not id or completed or isGuild or isStatistic then
    return nil
  end
  local criteria = readCriteria(id)
  if #criteria == 0 then
    return nil
  end
  local progress = Achievements.progress(criteria)
  return {
    name = name,
    done = progress.done,
    total = progress.total,
    fraction = progress.fraction,
    reward = (rewardText and rewardText ~= "") and rewardText or nil,
    group = top == DUNGEONS_AND_RAIDS,
  }
end

local function scan()
  local entries = {}
  for _, categoryID in ipairs(GetCategoryList()) do
    local top = topCategory(categoryID)
    if Achievements.isSoloCategory(top) then
      for index = 1, GetCategoryNumAchievements(categoryID, true) do
        local entry = readAchievement(categoryID, index, top)
        if entry then
          entries[#entries + 1] = entry
        end
      end
    end
  end
  return entries
end

local function achievementLines()
  if dirty or not cachedLines then
    local ok, entries = pcall(scan)
    cachedLines = ok and Achievements.lines(entries) or UNAVAILABLE
    dirty = false
  end
  return cachedLines
end

local function open()
  ns.Window.Show("achievements")
end

function Tracker.OnInit()
  -- CRITERIA_UPDATE fires often: only mark stale, rescan when next shown.
  ns.On("CRITERIA_UPDATE", function() dirty = true end)
  ns.On("ACHIEVEMENT_EARNED", function()
    dirty = true
    ns.Window.Refresh()
  end)
end

ns.Window.AddView("achievements", "Achievements", achievementLines)
ns.RegisterCommand("achievements", open, HELP_LINES)
ns.RegisterCommand("ach", open)
ns.RegisterModule("achievements", Tracker)
