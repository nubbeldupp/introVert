-- Chat filtering rules for Quiet groups. Pure: no WoW API calls.
local _, ns = ...

local Filter = {}

Filter.LEVELS = { "off", "all", "keywords", "leader" }
Filter.LEVEL_LIST = table.concat(Filter.LEVELS, ", ")

local VALID_LEVELS = {}
for _, level in ipairs(Filter.LEVELS) do
  VALID_LEVELS[level] = true
end

-- Words that mean "someone is talking to you" for each group role.
-- Damage dealers get none: "dps" mostly appears in recruiting spam.
local ROLE_WORDS = { TANK = "tank", HEALER = "heal" }

function Filter.isValidLevel(level)
  return VALID_LEVELS[level] == true
end

local function isBlank(text)
  return type(text) ~= "string" or not text:match("%S")
end

-- Returns a new lowercase list of words that make a line worth showing.
function Filter.buildNeedles(keywords, playerName, role)
  local needles = {}
  for _, keyword in ipairs(keywords or {}) do
    if not isBlank(keyword) then
      needles[#needles + 1] = keyword:lower()
    end
  end
  if not isBlank(playerName) then
    needles[#needles + 1] = playerName:lower()
  end
  if ROLE_WORDS[role] then
    needles[#needles + 1] = ROLE_WORDS[role]
  end
  return needles
end

local function containsAny(text, needles)
  local lower = text:lower()
  for _, needle in ipairs(needles) do
    if lower:find(needle, 1, true) then
      return true
    end
  end
  return false
end

local function effectiveLevel(options)
  if not Filter.isValidLevel(options.level) or options.level == "off" then
    return "off"
  end
  return options.strict and "all" or options.level
end

-- message: { text, isSelf, isLeader, isSecret }
-- options: { level, needles, strict }
-- Secret messages (unreadable during encounters) are shown unless the level
-- hides everything: missing a "wait" is worse than seeing one extra line.
function Filter.shouldHide(message, options)
  if message.isSelf then
    return false
  end
  local level = effectiveLevel(options)
  if level == "all" then
    return true
  end
  if level == "off" or message.isSecret then
    return false
  end
  if level == "leader" then
    return not message.isLeader
  end
  return not containsAny(message.text or "", options.needles or {})
end

ns.QuietFilter = Filter
