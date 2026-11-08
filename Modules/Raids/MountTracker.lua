-- Raid Farm Planner, part 2: counts mount attempts on boss kills and lists
-- missing raid mounts with /iv mounts.
local _, ns = ...

local Mounts = ns.RaidMounts

local KILL_SUCCESS = 1

local HELP_LINES = {
  "/iv mounts - missing raid mounts, attempts and free alts",
  "/iv mounts check - list mount data the game does not recognise",
  "/iv mounts set <mount> <count> - enter attempts from before introVert",
}

local SET_USAGE = "Usage: /iv mounts set <mount> <count>, e.g. /iv mounts set invincible 12"
local MAX_ATTEMPTS = 100000

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

local function matchNames(matches)
  local names = {}
  for index, match in ipairs(matches) do
    names[index] = match.name
  end
  table.sort(names)
  return table.concat(names, ", ")
end

local function setAttempts(args)
  local query, countText = args:match("^(.-)%s+(%d+)$")
  local count = tonumber(countText)
  if not query or query == "" or not count or count > MAX_ATTEMPTS then
    ns.Print(SET_USAGE)
    return
  end
  local matches = Mounts.match(ns.RaidMountData, lookupMount, query)
  if #matches == 0 then
    ns.Print(("No tracked mount matches '%s'."):format(query))
    return
  end
  if #matches > 1 then
    ns.Print(("Several mounts match '%s': %s. Be more specific."):format(query, matchNames(matches)))
    return
  end
  ns.UpdateSetting({ "attempts", matches[1].itemID }, count)
  ns.Print(("%s: attempts set to %d."):format(matches[1].name, count))
end

local function onCommand(input)
  local first, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
  local subcommand = first:lower()
  if subcommand == "check" then
    printCheck()
  elseif subcommand == "set" then
    setAttempts(rest)
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

-- Missing-mount data for other modules (Finder).
Tracker.Resolve = resolve

ns.Window.AddView("mounts", "Mounts", mountLines)
ns.RegisterCommand("mounts", onCommand, HELP_LINES)
ns.RegisterModule("mounts", Tracker)
ns.MountTracker = Tracker
