-- Raid Farm Planner, part 1: records each character's raid lockouts
-- (account-wide) and shows who is locked or free with /iv raids.
local _, ns = ...

local Lockouts = ns.RaidLockouts

local NO_DATA = "No lockouts recorded yet. Log in on each character once to record it."
local KILL_SUCCESS = 1

local HELP_LINES = {
  "/iv raids - raid lockouts of all your characters",
  "/iv raids <name> - who is locked or free for one raid",
  "/iv raids forget <Name-Realm> - remove a deleted character",
}

local Raids = {}

local function characters()
  return ns.db.characters
end

local function readSavedInstances()
  local entries = {}
  for index = 1, GetNumSavedInstances() do
    local name, _, reset, difficultyID, locked, extended, _, isRaid, _, difficultyName,
      numEncounters, encounterProgress, _, instanceID = GetSavedInstanceInfo(index)
    entries[#entries + 1] = {
      instanceID = instanceID,
      name = name, reset = reset, difficultyID = difficultyID, locked = locked,
      extended = extended, isRaid = isRaid, difficultyName = difficultyName,
      numEncounters = numEncounters, encounterProgress = encounterProgress,
    }
  end
  return entries
end

local function record()
  local now = time()
  ns.UpdateSetting({ "characters", ns.CharacterKey() }, {
    updatedAt = now,
    lockouts = Lockouts.fromSaved(readSavedInstances(), now),
  })
end

local function onEncounterEnd(_, _, _, _, _, success)
  local _, instanceType = IsInInstance()
  if success == KILL_SUCCESS and instanceType == "raid" then
    RequestRaidInfo()
  end
end

-- Slash commands ---------------------------------------------------------------

local function overviewLines()
  if next(characters()) == nil then
    return { NO_DATA }
  end
  return Lockouts.characterLines(characters(), time())
end

local function printRaid(query)
  local result = Lockouts.forRaid(characters(), query, time())
  for _, line in ipairs(result.locked) do
    ns.Print("Locked: " .. line)
  end
  local free = #result.free > 0 and table.concat(result.free, ", ") or "none"
  ns.Print("Free: " .. free)
end

local function findCharacter(name)
  local wanted = name:lower()
  for key in pairs(characters()) do
    if key:lower() == wanted then
      return key
    end
  end
  return nil
end

local function forget(name)
  local key = findCharacter(name)
  if not key then
    ns.Print(("No saved character named '%s'."):format(name))
    return
  end
  ns.UpdateSetting({ "characters", key }, nil)
  ns.Print(("Forgot %s."):format(key))
end

local function onCommand(input)
  local args = input:match("^%s*(.-)%s*$")
  local first, rest = args:match("^(%S*)%s*(.-)$")
  if first:lower() == "forget" and rest ~= "" then
    forget(rest)
    return
  end
  if args == "" then
    ns.Window.Show("raids")
    return
  end
  if next(characters()) == nil then
    ns.Print(NO_DATA)
    return
  end
  printRaid(args)
end

function Raids.OnInit()
  ns.On("PLAYER_ENTERING_WORLD", function() RequestRaidInfo() end)
  ns.On("UPDATE_INSTANCE_INFO", record)
  ns.On("ENCOUNTER_END", onEncounterEnd)
end

ns.Window.AddView("raids", "Raids", overviewLines)
ns.RegisterCommand("raids", onCommand, HELP_LINES)
ns.RegisterModule("raids", Raids)
