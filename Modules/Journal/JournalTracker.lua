-- Session journal: logs what each play session achieved (boss kills,
-- delves, Labyrinth chambers, achievements, mount attempts, gold) and shows
-- the last session's summary on the next login. A login starts a session;
-- a /reload continues it.
local _, ns = ...

local Journal = ns.Journal

local KILL_SUCCESS = 1
local BOSS_INSTANCE_TYPES = { raid = true, party = true }
local TIME_FORMAT = "%H:%M"
local DAY_FORMAT = "%b %d %H:%M"
local HELP_LINES = { "/iv journal - what you did this session and in earlier ones" }

local CLOCK = {
  time = function(at) return date(TIME_FORMAT, at) end,
  day = function(at) return date(DAY_FORMAT, at) end,
}

local Tracker = {}

local function sessions()
  return ns.db.journal.sessions
end

local function save(list)
  ns.UpdateSetting({ "journal", "sessions" }, list)
end

local function currentIndex()
  return Journal.currentIndex(sessions(), ns.CharacterKey())
end

-- Replaces this character's current session with change(session); events
-- before the first session (e.g. while loading) are ignored.
local function update(change)
  local index = currentIndex()
  if not index then
    return
  end
  save(Journal.replaceAt(sessions(), index, change(sessions()[index])))
end

local function log(kind, text)
  update(function(session) return Journal.addEntry(session, kind, text, time()) end)
end

local function printLastSession()
  local index = currentIndex()
  local summary = index and Journal.summary(sessions()[index])
  if summary and ns.db.journal.loginSummary then
    ns.Print(("Last session: %s."):format(summary))
  end
end

local function startSession()
  save(Journal.startSession(sessions(), Journal.newSession(ns.CharacterKey(), time(), GetMoney())))
end

local function onEnteringWorld(_, isInitialLogin)
  if isInitialLogin then
    printLastSession()
    startSession()
  elseif not currentIndex() then
    startSession()
  end
end

local function onEncounterEnd(_, _, encounterName, _, _, success)
  if success ~= KILL_SUCCESS then
    return
  end
  local instanceName, instanceType = GetInstanceInfo()
  if BOSS_INSTANCE_TYPES[instanceType] then
    log("boss", ("Boss: %s (%s)"):format(encounterName, instanceName))
  end
end

local function onAchievementEarned(_, achievementID, alreadyEarned)
  if alreadyEarned then
    return
  end
  local _, name = GetAchievementInfo(achievementID)
  log("achievement", "Achievement: " .. (name or tostring(achievementID)))
end

function Tracker.OnInit()
  ns.On("PLAYER_ENTERING_WORLD", onEnteringWorld)
  ns.On("ENCOUNTER_END", onEncounterEnd)
  ns.On("ACHIEVEMENT_EARNED", onAchievementEarned)
  ns.On("PLAYER_MONEY", function()
    update(function(session) return Journal.withGold(session, GetMoney(), time()) end)
  end)
  ns.On("PLAYER_LOGOUT", function()
    update(function(session) return Journal.touch(session, time()) end)
  end)
  ns.Subscribe("DelveRecorded", function(name, tier)
    log("delve", ("Delve: %s, tier %s"):format(name, tier or "?"))
  end)
  ns.Subscribe("LabyrinthChamber", function(_, tier, visitChambers)
    log("chamber", ("Labyrinth chamber %d, tier %s"):format(visitChambers, tier or "?"))
  end)
  ns.Subscribe("MountAttempt", function(mountName, count)
    log("attempt", ("Mount attempt %d: %s"):format(count, mountName))
  end)
end

local function journalLines()
  return Journal.lines(sessions(), ns.CharacterKey(), time(), CLOCK)
end

ns.Options.AddSection(function(ui)
  ui.header("Session Journal")
  ui.checkbox({ "journal", "loginSummary" }, "Show last session on login",
    "One chat line on login with what your last session achieved.")
end)

ns.Window.AddView("journal", "Journal", journalLines)
ns.RegisterCommand("journal", function() ns.Window.Show("journal") end, HELP_LINES)
ns.RegisterModule("journal", Tracker)
