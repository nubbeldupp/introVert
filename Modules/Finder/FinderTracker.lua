-- Solo Content Finder: plans a solo session from what the other modules
-- know. Each source is read safely, so one broken API never empties the plan.
local _, ns = ...

local Finder = ns.Finder

local MIN_BUDGET = 5
local MAX_BUDGET = 600
local SLIDER_RANGE = { min = 15, max = 180, step = 15 }
local HELP_LINES = {
  "/iv finder [minutes] - plan a solo session from raids, delves and achievements (also /iv solo)",
}

local function safely(read, fallback)
  local ok, value = pcall(read)
  if ok and value ~= nil then
    return value
  end
  return fallback
end

local function lockedInstances()
  local me = ns.db.characters[ns.CharacterKey()]
  local locked = {}
  for _, lockout in ipairs(ns.RaidLockouts.active(me and me.lockouts, time())) do
    if lockout.instanceID then
      locked[lockout.instanceID] = true
    end
  end
  return locked
end

local function suggestions()
  local raids = safely(function() return ns.MountTracker.Resolve().raids end, {})
  local vault = safely(ns.DelveTracker.ReadVault, {})
  local bountiful = safely(ns.DelveTracker.ReadBountiful, {})
  local result = Finder.mountSuggestions(raids, lockedInstances())
  for _, suggestion in ipairs(Finder.delveSuggestions(bountiful, Finder.vaultOpen(vault))) do
    result[#result + 1] = suggestion
  end
  return result
end

local function finderLines()
  local budget = ns.db.finder.minutes
  local achievements = safely(ns.AchievementTracker.Entries, {})
  return Finder.lines(Finder.plan(suggestions(), budget), budget, achievements)
end

local function onCommand(input)
  local text = input:match("^%s*(.-)%s*$")
  if text ~= "" then
    local minutes = tonumber(text)
    if not minutes or minutes < MIN_BUDGET or minutes > MAX_BUDGET then
      ns.Print(("Give a session length between %d and %d minutes, e.g. /iv finder 45."):format(MIN_BUDGET, MAX_BUDGET))
      return
    end
    ns.UpdateSetting({ "finder", "minutes" }, math.floor(minutes))
  end
  ns.Window.Show("finder")
end

ns.Options.AddSection(function(ui)
  ui.header("Solo Content Finder")
  ui.slider({ "finder", "minutes" }, "Session length (minutes)", SLIDER_RANGE,
    "Default time budget for /iv finder.")
end)

ns.Window.AddView("finder", "Finder", finderLines)
ns.RegisterCommand("finder", onCommand, HELP_LINES)
ns.RegisterCommand("solo", onCommand)
