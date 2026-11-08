-- Default settings and pure helpers for building settings tables.
-- Nothing here mutates its inputs; every helper returns a new table.
local _, ns = ...

local Defaults = {}

Defaults.SCHEMA_VERSION = 1

Defaults.values = {
  schemaVersion = Defaults.SCHEMA_VERSION,
  quiet = {
    enabled = { dungeon = true, lfr = true },
    chatLevel = { dungeon = "keywords", lfr = "keywords" },
    keywords = { "wait", "afk", "kick", "brb" },
    greetings = { "hi o/", "hey", "o/" },
    farewells = { "ty all", "thanks!", "gg ty" },
    greet = true,
    farewell = true,
    readyAlarm = true,
    encounterFocus = true,
    wipeMuteSeconds = 30,
  },
}

-- A table counts as a list when it is empty or has a sequence part.
local function isList(value)
  return type(value) == "table" and (#value > 0 or next(value) == nil)
end

local function deepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for key, inner in pairs(value) do
    copy[key] = deepCopy(inner)
  end
  return copy
end

Defaults.deepCopy = deepCopy

-- Returns a new table: `defaults` overlaid with values from `saved` whose
-- type matches. Unknown keys in `saved` are dropped, missing keys get defaults.
function Defaults.merge(defaults, saved)
  if type(saved) ~= "table" then
    return deepCopy(defaults)
  end
  local result = {}
  for key, defaultValue in pairs(defaults) do
    local savedValue = saved[key]
    if type(defaultValue) == "table" and not isList(defaultValue) then
      result[key] = Defaults.merge(defaultValue, savedValue)
    elseif savedValue ~= nil and type(savedValue) == type(defaultValue) then
      result[key] = deepCopy(savedValue)
    else
      result[key] = deepCopy(defaultValue)
    end
  end
  return result
end

-- Returns the value at `path` (list of keys), or nil if any step is missing.
function Defaults.get(tbl, path)
  local cursor = tbl
  for _, key in ipairs(path) do
    if type(cursor) ~= "table" then
      return nil
    end
    cursor = cursor[key]
  end
  return cursor
end

-- Returns a copy of `tbl` with the value at `path` (list of keys) replaced.
function Defaults.with(tbl, path, value)
  local copy = deepCopy(tbl)
  local cursor = copy
  for index = 1, #path - 1 do
    local key = path[index]
    if type(cursor[key]) ~= "table" then
      cursor[key] = {}
    end
    cursor = cursor[key]
  end
  cursor[path[#path]] = deepCopy(value)
  return copy
end

ns.Defaults = Defaults
