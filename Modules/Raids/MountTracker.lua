-- Raid Farm Planner, part 2: counts mount attempts on boss kills and lists
-- missing raid mounts with /iv mounts.
local _, ns = ...

local Mounts = ns.RaidMounts

local KILL_SUCCESS = 1

local HELP_LINES = {
  "/iv mounts - missing raid mounts, attempts and free alts",
  "/iv mounts check - list mount data the game does not recognise",
}

local Tracker = {}

-- The item -> mount lookup returns nothing for items the client has not
-- loaded yet (old raid items usually are not), so ask for them first.
local function isCached(itemID)
  return C_Item.IsItemDataCachedByID(itemID)
end

local function requestItems()
  for _, raid in ipairs(ns.RaidMountData.raids) do
    for _, mount in ipairs(raid.mounts) do
      C_Item.RequestLoadItemDataByID(mount.itemID)
    end
  end
end

-- Resolves a mount item through the mount journal: { pending = true } while
-- the item loads, nil when it is not a mount.
local function lookupMount(itemID)
  if not isCached(itemID) then
    C_Item.RequestLoadItemDataByID(itemID)
    return { pending = true }
  end
  local mountID = C_MountJournal.GetMountFromItem(itemID)
  if not mountID then
    return nil
  end
  local name, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
  if not name then
    return nil
  end
  return { name = name, collected = isCollected == true }
end

local function attempts()
  return ns.db.attempts
end

local function countAttempt(itemID)
  local mount = lookupMount(itemID)
  if not mount or mount.collected then
    return
  end
  local count = (attempts()[itemID] or 0) + 1
  ns.UpdateSetting({ "attempts", itemID }, count)
  ns.Print(("Attempt %d for %s."):format(count, mount.name))
end

local function onEncounterEnd(_, _, encounterName, _, _, success)
  if success ~= KILL_SUCCESS then
    return
  end
  local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
  if instanceType ~= "raid" then
    return
  end
  for _, itemID in ipairs(Mounts.attemptItems(ns.RaidMountData, instanceID, difficultyID, encounterName)) do
    countAttempt(itemID)
  end
end

local function resolve()
  return Mounts.resolve(ns.RaidMountData, lookupMount)
end

local function mountLines()
  return Mounts.lines(resolve(), attempts(), ns.db.characters, time())
end

local function printCheck()
  local resolved = resolve()
  if resolved.pending > 0 then
    ns.Print(("%d items are still loading; run the check again in a few seconds."):format(resolved.pending))
  end
  if #resolved.unresolved == 0 and resolved.pending == 0 then
    ns.Print(("All %d tracked items are known mounts."):format(resolved.known))
    return
  end
  for _, item in ipairs(resolved.unresolved) do
    ns.Print(("Not a known mount: item %d (%s, %s)"):format(item.itemID, item.raid, item.boss))
  end
end

local function onCommand(input)
  if input:match("^%s*(%S*)"):lower() == "check" then
    printCheck()
  else
    ns.Window.Show("mounts")
  end
end

function Tracker.OnInit()
  requestItems()
  ns.On("ENCOUNTER_END", onEncounterEnd)
  -- Mount items load in the background; redraw so "Still loading" clears.
  ns.On("ITEM_DATA_LOAD_RESULT", function() ns.Window.Refresh() end)
end

ns.Window.AddView("mounts", "Mounts", mountLines)
ns.RegisterCommand("mounts", onCommand, HELP_LINES)
ns.RegisterModule("mounts", Tracker)
