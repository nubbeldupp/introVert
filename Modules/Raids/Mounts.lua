-- Raid mount logic: missing mounts, attempt matching, display lines.
-- Pure: the mount lookup and current time are passed in.
local _, ns = ...

local Mounts = {}

local function contains(list, value)
  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end
  return false
end

local function sortedKeys(map)
  local keys = {}
  for key in pairs(map or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

-- lookup(itemID) -> { name, collected }, { pending = true } while the client
-- is still loading the item, or nil when the item is not a mount.
function Mounts.resolve(data, lookup)
  local result = { raids = {}, unresolved = {}, collected = 0, known = 0, pending = 0 }
  for _, raid in ipairs(data.raids) do
    local missing = {}
    for _, mount in ipairs(raid.mounts) do
      local info = lookup(mount.itemID)
      if info and info.pending then
        result.pending = result.pending + 1
      elseif not info then
        result.unresolved[#result.unresolved + 1] = { itemID = mount.itemID, raid = raid.name, boss = mount.boss }
      else
        result.known = result.known + 1
        if info.collected then
          result.collected = result.collected + 1
        else
          missing[#missing + 1] = { itemID = mount.itemID, mountName = info.name, boss = mount.boss, note = mount.note }
        end
      end
    end
    if #missing > 0 then
      result.raids[#result.raids + 1] = {
        instanceID = raid.instanceID, name = raid.name, minutes = raid.minutes, missing = missing,
      }
    end
  end
  return result
end

-- Tracked mounts whose name matches `query` (plain, case-insensitive).
-- An exact name match wins over partial ones. Returns { { itemID, name } }.
function Mounts.match(data, lookup, query)
  local wanted = query:lower()
  local exact, partial = {}, {}
  for _, raid in ipairs(data.raids) do
    for _, mount in ipairs(raid.mounts) do
      local info = lookup(mount.itemID)
      if info and info.name then
        local name = info.name:lower()
        local hit = { itemID = mount.itemID, name = info.name }
        if name == wanted then
          exact[#exact + 1] = hit
        elseif name:find(wanted, 1, true) then
          partial[#partial + 1] = hit
        end
      end
    end
  end
  return #exact > 0 and exact or partial
end

-- Item IDs whose drop chance this kill counted as an attempt for.
function Mounts.attemptItems(data, instanceID, difficultyID, encounterName)
  local wanted = (encounterName or ""):lower()
  local items = {}
  for _, raid in ipairs(data.raids) do
    if raid.instanceID == instanceID then
      for _, mount in ipairs(raid.mounts) do
        local difficultyOk = not mount.difficulties or contains(mount.difficulties, difficultyID)
        if mount.boss:lower() == wanted and difficultyOk then
          items[#items + 1] = mount.itemID
        end
      end
    end
  end
  return items
end

local function isLocked(lockouts, instanceID, now)
  for _, lockout in ipairs(lockouts or {}) do
    if lockout.instanceID == instanceID and lockout.expiresAt > now then
      return true
    end
  end
  return false
end

function Mounts.freeCharacters(characters, instanceID, now)
  local free = {}
  for _, name in ipairs(sortedKeys(characters)) do
    if not isLocked(characters[name].lockouts, instanceID, now) then
      free[#free + 1] = name
    end
  end
  return free
end

local function mountLine(mount, count)
  local note = mount.note and (" (" .. mount.note .. ")") or ""
  local unit = count == 1 and "attempt" or "attempts"
  return ("  %s - %s%s, %d %s"):format(mount.mountName, mount.boss, note, count, unit)
end

function Mounts.lines(resolved, attempts, characters, now)
  local lines = {}
  for _, raid in ipairs(resolved.raids) do
    local free = Mounts.freeCharacters(characters, raid.instanceID, now)
    local freeText = #free > 0 and table.concat(free, ", ") or "none this week"
    lines[#lines + 1] = ("%s - free: %s"):format(raid.name, freeText)
    for _, mount in ipairs(raid.missing) do
      lines[#lines + 1] = mountLine(mount, (attempts or {})[mount.itemID] or 0)
    end
  end
  lines[#lines + 1] = ("Collected %d of %d tracked raid mounts."):format(resolved.collected, resolved.known)
  if (resolved.pending or 0) > 0 then
    lines[#lines + 1] = ("Still loading %d mounts from the game, try again in a few seconds."):format(resolved.pending)
  end
  return lines
end

ns.RaidMounts = Mounts
