-- Parses "/iv quiet ..." input into an action table. Pure.
local _, ns = ...

local Profile = ns.QuietProfile
local Filter = ns.QuietFilter

local Commands = {}

local function words(input)
  local result = {}
  for word in (input or ""):lower():gmatch("%S+") do
    result[#result + 1] = word
  end
  return result
end

function Commands.parse(input)
  local args = words(input)
  local first, second = args[1], args[2]

  if not first or first == "status" then
    return { action = "status" }
  end
  if first == "on" or first == "off" then
    return { action = "enable", value = first == "on" }
  end
  if first == "log" then
    return { action = "log" }
  end
  if Profile.isValid(first) then
    if Filter.isValidLevel(second) then
      return { action = "level", profile = first, value = second }
    end
    local message = ("Unknown chat level '%s'. Use one of: %s"):format(second or "", Filter.LEVEL_LIST)
    return { action = "error", message = message }
  end
  return { action = "help" }
end

ns.QuietCommands = Commands
