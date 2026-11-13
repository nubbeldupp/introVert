-- Raid mount logic: missing mounts, attempt matching, display lines.
-- Pure: the mount lookup and current time are passed in; durations reuse
-- ns.RaidLockouts.formatDuration.
local _, ns = ...

local Mounts = {}

local INDENT = "  "
local CHARACTER_INDENT = "    "
local CLOSED_MARKER = "[+] "
local OPEN_MARKER = "[-] "
local HINT = "Click a mount to show or hide your characters."
local NO_LOCKOUT = "no lockout, farm any time"

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

-- Raids and dungeons in one new list, raids first.
function Mounts.allInstances(data)
  local list = {}
  for _, group in ipairs({ data.raids or {}, data.dungeons or {} }) do
    for _, instance in ipairs(group) do
      list[#list + 1] = instance
    end
  end
  return list
end

-- Resolves one group (raids or dungeons) into `result`; returns the
-- instances that still have missing mounts.
local function resolveGroup(instances, lookup, result)
  local group = {}
  for _, instance in ipairs(instances or {}) do
    local missing = {}
    for _, mount in ipairs(instance.mounts) do
      local info = lookup(mount.itemID)
      if info and info.pending then
        result.pending = result.pending + 1
      elseif not info then
        result.unresolved[#result.unresolved + 1] = { itemID = mount.itemID, raid = instance.name, boss = mount.boss }
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
      group[#group + 1] = {
        instanceID = instance.instanceID, name = instance.name, minutes = instance.minutes, missing = missing,
      }
    end
  end
  return group
end

-- lookup(itemID) -> { name, collected }, { pending = true } while the client
-- is still loading the item, or nil when the item is not a mount.
function Mounts.resolve(data, lookup)
  local result = { unresolved = {}, collected = 0, known = 0, pending = 0 }
  result.raids = resolveGroup(data.raids, lookup, result)
  result.dungeons = resolveGroup(data.dungeons, lookup, result)
  return result
end

-- Tracked mounts whose name matches `query` (plain, case-insensitive).
-- An exact name match wins over partial ones. Returns { { itemID, name } }.
function Mounts.match(data, lookup, query)
  local wanted = query:lower()
  local exact, partial = {}, {}
  for _, raid in ipairs(Mounts.allInstances(data)) do
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
  for _, raid in ipairs(Mounts.allInstances(data)) do
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

local function activeLockout(lockouts, instanceID, now)
  for _, lockout in ipairs(lockouts or {}) do
    if lockout.instanceID == instanceID and lockout.expiresAt > now then
      return lockout
    end
  end
  return nil
end

-- Every character with its active lockout for the raid, sorted by name:
-- { { name, expiresAt } }, expiresAt nil when the character is free.
function Mounts.characterStatus(characters, instanceID, now)
  local statuses = {}
  for _, name in ipairs(sortedKeys(characters)) do
    local lockout = activeLockout(characters[name].lockouts, instanceID, now)
    statuses[#statuses + 1] = { name = name, expiresAt = lockout and lockout.expiresAt }
  end
  return statuses
end

-- "Name-Realm" -> "Name" on the current realm; other realms stay visible.
function Mounts.shortName(key, realm)
  local name, keyRealm = key:match("^([^-]+)-(.+)$")
  if name and keyRealm == realm then
    return name
  end
  return key
end

local function countFree(statuses)
  local free = 0
  for _, status in ipairs(statuses) do
    if not status.expiresAt then
      free = free + 1
    end
  end
  return free
end

-- One-line status: how many characters can still kill the boss this week.
-- Counts only, so it stays short with many alts.
local function summary(statuses)
  local total = #statuses
  local free = countFree(statuses)
  if total == 0 then
    return "no characters recorded yet"
  end
  if total == 1 then
    return free == 1 and "free" or "locked until reset"
  end
  if free == total then
    return ("free on all %d characters"):format(total)
  end
  return ("free on %d of %d characters"):format(free, total)
end

local function coloredName(status, context)
  local name = Mounts.shortName(status.name, context.realm)
  local color = context.colorOf(status.name)
  return color and ("|c%s%s|r"):format(color, name) or name
end

local function characterLine(status, context)
  local state = "free"
  if status.expiresAt then
    state = "locked, resets in " .. ns.RaidLockouts.formatDuration(status.expiresAt - context.now)
  end
  return ("%s%s - %s"):format(CHARACTER_INDENT, coloredName(status, context), state)
end

local function mountTitle(mount, count)
  local note = mount.note and (" (" .. mount.note .. ")") or ""
  local unit = count == 1 and "attempt" or "attempts"
  return ("%s - %s%s, %d %s"):format(mount.mountName, mount.boss, note, count, unit)
end

local function plainLink(_, text)
  return text
end

local function neverExpanded()
  return false
end

local function noColor()
  return nil
end

-- A clickable raid mount row, its status line, and the characters when opened.
local function appendRaidMount(lines, raid, mount, context)
  local key = tostring(mount.itemID)
  local isOpen = context.isExpanded(key)
  local marker = isOpen and OPEN_MARKER or CLOSED_MARKER
  local statuses = Mounts.characterStatus(context.characters, raid.instanceID, context.now)
  local count = context.attempts[mount.itemID] or 0
  lines[#lines + 1] = context.link(key, marker .. mountTitle(mount, count))
  lines[#lines + 1] = ("%s%s: %s"):format(INDENT, raid.name, summary(statuses))
  if isOpen then
    for _, status in ipairs(statuses) do
      lines[#lines + 1] = characterLine(status, context)
    end
  end
end

-- Legacy dungeons have no lockout, so there is nothing per character to show.
local function appendDungeonMount(lines, dungeon, mount, context)
  local count = context.attempts[mount.itemID] or 0
  lines[#lines + 1] = mountTitle(mount, count)
  lines[#lines + 1] = ("%s%s: %s"):format(INDENT, dungeon.name, NO_LOCKOUT)
end

-- A section header, then each missing mount separated by an empty line.
local function appendSection(lines, header, instances, appendMount, context)
  if #instances == 0 then
    return
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = header
  local first = true
  for _, instance in ipairs(instances) do
    for _, mount in ipairs(instance.missing) do
      if not first then
        lines[#lines + 1] = ""
      end
      first = false
      appendMount(lines, instance, mount, context)
    end
  end
end

-- options: { realm, link(key, text), isExpanded(key), colorOf(characterKey) }
-- where colorOf returns an "aarrggbb" class colour or nil. Without options
-- every row is plain, collapsed and uncoloured.
function Mounts.lines(resolved, attempts, characters, now, options)
  local settings = options or {}
  local context = {
    attempts = attempts or {}, characters = characters, now = now, realm = settings.realm,
    link = settings.link or plainLink, isExpanded = settings.isExpanded or neverExpanded,
    colorOf = settings.colorOf or noColor,
  }
  local lines = {}
  local raids, dungeons = resolved.raids or {}, resolved.dungeons or {}
  if #raids > 0 then
    lines[1] = HINT
  end
  appendSection(lines, "Raid mounts", raids, appendRaidMount, context)
  appendSection(lines, "Dungeon mounts", dungeons, appendDungeonMount, context)
  if #lines > 0 then
    lines[#lines + 1] = ""
  end
  lines[#lines + 1] = ("Collected %d of %d tracked mounts."):format(resolved.collected, resolved.known)
  if (resolved.pending or 0) > 0 then
    lines[#lines + 1] = ("Still loading %d mounts from the game, try again in a few seconds."):format(resolved.pending)
  end
  return lines
end

ns.RaidMounts = Mounts
