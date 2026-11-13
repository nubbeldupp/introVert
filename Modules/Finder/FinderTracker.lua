-- Solo Content Finder: plans a solo session from what the other modules
-- know and keeps it as a checklist that ticks itself off (raid lockout
-- gained, delve recorded). Each source is read safely, so one broken API
-- never empties the plan.
local _, ns = ...

local Finder = ns.Finder

local MIN_BUDGET = 5
local MAX_BUDGET = 600
local SLIDER_RANGE = { min = 15, max = 180, step = 15 }
local HELP_LINES = {
  "/iv finder [minutes] - plan a solo session from raids, delves and achievements (also /iv solo)",
  "/iv finder new - start a fresh checklist",
}

local Tracker = {}

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

local function currentPlan()
  return Finder.plan(suggestions(), ns.db.finder.minutes)
end

local function savedChecklist()
  return (ns.db.finder.checklists or {})[ns.CharacterKey()]
end

-- Freezes the current plan as this character's checklist (saved, so it
-- survives /reload).
local function startChecklist(plan)
  local checklist = Finder.newChecklist(plan, ns.db.finder.minutes, time())
  ns.UpdateSetting({ "finder", "checklists", ns.CharacterKey() }, checklist)
  return checklist
end

local function progressFor(checklist)
  local progress = { locked = lockedInstances(), delves = ns.db.delves or {}, since = checklist.createdAt }
  return { isDone = function(item) return Finder.isDone(item, progress) end }
end

local function finderLines()
  local plan = currentPlan()
  local checklist = savedChecklist() or startChecklist(plan)
  local achievements = safely(ns.AchievementTracker.Entries, {})
  return Finder.lines(checklist, progressFor(checklist), Finder.otherSuggestions(plan, checklist), achievements)
end

-- A new login is a new session; a /reload keeps the checklist.
local function onEnteringWorld(_, isInitialLogin)
  if isInitialLogin and savedChecklist() then
    ns.UpdateSetting({ "finder", "checklists", ns.CharacterKey() }, nil)
  end
end

local function setBudget(text)
  local minutes = tonumber(text)
  if not minutes or minutes < MIN_BUDGET or minutes > MAX_BUDGET then
    ns.Print(("Give a session length between %d and %d minutes, e.g. /iv finder 45."):format(MIN_BUDGET, MAX_BUDGET))
    return false
  end
  ns.UpdateSetting({ "finder", "minutes" }, math.floor(minutes))
  return true
end

local function onCommand(input)
  local text = input:match("^%s*(.-)%s*$")
  if text:lower() == "new" then
    startChecklist(currentPlan())
  elseif text ~= "" then
    if not setBudget(text) then
      return
    end
    startChecklist(currentPlan())
  end
  ns.Window.Show("finder")
end

function Tracker.OnInit()
  ns.On("PLAYER_ENTERING_WORLD", onEnteringWorld)
end

ns.Options.AddSection(function(ui)
  ui.header("Solo Content Finder")
  ui.slider({ "finder", "minutes" }, "Session length (minutes)", SLIDER_RANGE,
    "Default time budget for /iv finder.")
end)

ns.Window.AddView("finder", "Finder", finderLines)
ns.RegisterCommand("finder", onCommand, HELP_LINES)
ns.RegisterCommand("solo", onCommand)
ns.RegisterModule("finder", Tracker)
