-- Delve Companion: records finished delves and shows Great Vault progress,
-- today's bountiful delves and your delve history in the Delves tab.
-- Every game API read is guarded: a failing section shows "Not available"
-- instead of breaking the window.
local _, ns = ...

local Delves = ns.Delves

local DELVE_DIFFICULTY = 208
local COSMIC_MAP_ID = 946
local BOUNTIFUL_ATLAS = "delves-bountiful"
local UNAVAILABLE = { "  Not available on this client." }
local HELP_LINES = { "/iv delves - Great Vault progress, bountiful delves and your delve history" }

local Tracker = {}

local function safeSection(read, format)
  local ok, lines = pcall(function() return format(read()) end)
  if ok then
    return lines
  end
  return UNAVAILABLE
end

local function readVault()
  return C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)
end

local function collectBountiful(zone, seen, found)
  for _, poiID in ipairs(C_AreaPoiInfo.GetDelvesForMap(zone.mapID) or {}) do
    if not seen[poiID] then
      seen[poiID] = true
      local info = C_AreaPoiInfo.GetAreaPOIInfo(zone.mapID, poiID)
      if info and info.atlasName == BOUNTIFUL_ATLAS then
        found[#found + 1] = { name = info.name, zone = zone.name }
      end
    end
  end
end

-- Walks every zone map so no zone IDs need to be hard-coded.
local function readBountiful()
  local found, seen = {}, {}
  for _, zone in ipairs(C_Map.GetMapChildrenInfo(COSMIC_MAP_ID, Enum.UIMapType.Zone, true) or {}) do
    collectBountiful(zone, seen, found)
  end
  return found
end

local function delveLines()
  return Delves.lines(
    safeSection(readVault, Delves.vaultLines),
    safeSection(readBountiful, Delves.bountifulLines),
    Delves.historyLines(ns.db.delves)
  )
end

local function onScenarioCompleted()
  local name, _, difficultyID, difficultyName = GetInstanceInfo()
  if difficultyID ~= DELVE_DIFFICULTY then
    return
  end
  local tier = Delves.parseTier(difficultyName)
  ns.UpdateSetting({ "delves" }, Delves.record(ns.db.delves, name, tier, time()))
  ns.Print(("Delve recorded: %s, tier %s."):format(name, tier or "?"))
end

function Tracker.OnInit()
  ns.On("SCENARIO_COMPLETED", onScenarioCompleted)
  ns.On("WEEKLY_REWARDS_UPDATE", function() ns.Window.Refresh() end)
end

ns.Window.AddView("delves", "Delves", delveLines)
ns.RegisterCommand("delves", function() ns.Window.Show("delves") end, HELP_LINES)
ns.RegisterModule("delves", Tracker)
