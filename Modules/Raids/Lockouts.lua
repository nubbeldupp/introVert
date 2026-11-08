-- Raid lockout records across characters. Pure: times are passed in.
local _, ns = ...

local Lockouts = {}

local MINUTE = 60
local HOUR = 60 * MINUTE
local DAY = 24 * HOUR

local function byName(a, b)
  return a.name < b.name
end

local function sortedKeys(map)
  local keys = {}
  for key in pairs(map or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

-- entries: GetSavedInstanceInfo results as tables. Keeps locked or extended
-- raids and turns "seconds until reset" into an absolute expiry time.
function Lockouts.fromSaved(entries, now)
  local result = {}
  for _, entry in ipairs(entries or {}) do
    if entry.isRaid and (entry.locked or entry.extended) then
      result[#result + 1] = {
        instanceID = entry.instanceID,
        name = entry.name,
        difficultyName = entry.difficultyName,
        progress = entry.encounterProgress,
        total = entry.numEncounters,
        expiresAt = now + entry.reset,
      }
    end
  end
  table.sort(result, byName)
  return result
end

function Lockouts.active(lockouts, now)
  local result = {}
  for _, lockout in ipairs(lockouts or {}) do
    if lockout.expiresAt > now then
      result[#result + 1] = lockout
    end
  end
  return result
end

function Lockouts.formatDuration(seconds)
  local value = math.max(seconds, MINUTE)
  if value >= DAY then
    return ("%dd %dh"):format(math.floor(value / DAY), math.floor((value % DAY) / HOUR))
  end
  if value >= HOUR then
    return ("%dh %dm"):format(math.floor(value / HOUR), math.floor((value % HOUR) / MINUTE))
  end
  return ("%dm"):format(math.floor(value / MINUTE))
end

local DETAIL_INDENT = "  "
local NO_LOCKOUTS = "no active raid lockouts"
local SHORT_DIFFICULTY = { ["Looking For Raid"] = "LFR" }

local function describe(lockout, now)
  local difficulty = SHORT_DIFFICULTY[lockout.difficultyName] or lockout.difficultyName
  return ("%s (%s) %d/%d, resets in %s"):format(
    lockout.name, difficulty, lockout.progress, lockout.total,
    Lockouts.formatDuration(lockout.expiresAt - now))
end

local function describeAll(lockouts, now)
  local parts = {}
  for _, lockout in ipairs(lockouts) do
    parts[#parts + 1] = describe(lockout, now)
  end
  return table.concat(parts, " | ")
end

-- Character name as a header, then one indented line per active lockout.
function Lockouts.characterLines(characters, now)
  local lines = {}
  for _, name in ipairs(sortedKeys(characters)) do
    lines[#lines + 1] = name
    local active = Lockouts.active(characters[name].lockouts, now)
    if #active == 0 then
      lines[#lines + 1] = DETAIL_INDENT .. NO_LOCKOUTS
    end
    for _, lockout in ipairs(active) do
      lines[#lines + 1] = DETAIL_INDENT .. describe(lockout, now)
    end
  end
  return lines
end

local function matching(lockouts, query)
  local result = {}
  for _, lockout in ipairs(lockouts) do
    if lockout.name:lower():find(query, 1, true) then
      result[#result + 1] = lockout
    end
  end
  return result
end

-- Splits characters into those locked to raids matching `query` (plain,
-- case-insensitive substring) and those still free.
function Lockouts.forRaid(characters, query, now)
  local wanted = query:lower()
  local result = { locked = {}, free = {} }
  for _, name in ipairs(sortedKeys(characters)) do
    local hits = matching(Lockouts.active(characters[name].lockouts, now), wanted)
    if #hits > 0 then
      result.locked[#result.locked + 1] = name .. ": " .. describeAll(hits, now)
    else
      result.free[#result.free + 1] = name
    end
  end
  return result
end

ns.RaidLockouts = Lockouts
