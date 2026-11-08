-- Alts tab: records level, item level, gold and Great Vault progress of the
-- logged-in character (account-wide) and lists all characters.
local _, ns = ...

local Alts = ns.Alts

local WEEK_SECONDS = 7 * 24 * 3600
local RECORD_EVENTS = {
  "PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "PLAYER_EQUIPMENT_CHANGED",
  "PLAYER_LEVEL_UP", "WEEKLY_REWARDS_UPDATE",
}
local HELP_LINES = { "/iv alts - level, item level, gold and Great Vault of all your characters" }

local Tracker = {}

local function safely(read, fallback)
  local ok, value = pcall(read)
  if ok and value ~= nil then
    return value
  end
  return fallback
end

local function readVault()
  local rows = Enum.WeeklyRewardChestThresholdType
  local types = { raid = rows.Raid, dungeon = rows.Activities, world = rows.World }
  return Alts.vaultSummary(C_WeeklyRewards.GetActivities(), types)
end

local function snapshot()
  local _, equipped = GetAverageItemLevel()
  local race = UnitRace("player")
  local class = UnitClass("player")
  return {
    level = UnitLevel("player"),
    race = race,
    class = class,
    itemLevel = math.floor(equipped or 0),
    gold = GetMoney(),
    vault = safely(readVault, nil),
    hasRewards = safely(function() return C_WeeklyRewards.HasAvailableRewards() end, false),
    updatedAt = time(),
  }
end

local function record()
  ns.UpdateSetting({ "alts", ns.CharacterKey() }, snapshot())
end

local function lastWeeklyReset()
  local untilReset = safely(function() return C_DateAndTime.GetSecondsUntilWeeklyReset() end, nil)
  if not untilReset then
    return 0
  end
  return time() + untilReset - WEEK_SECONDS
end

local function altLines()
  return Alts.lines(ns.db.alts, time(), lastWeeklyReset(), ns.CharacterKey())
end

function Tracker.OnInit()
  for _, event in ipairs(RECORD_EVENTS) do
    ns.On(event, record)
  end
end

ns.Window.AddView("alts", "Alts", altLines)
ns.RegisterCommand("alts", function() ns.Window.Show("alts") end, HELP_LINES)
ns.RegisterModule("alts", Tracker)
