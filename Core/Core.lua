-- Addon bootstrap: event bus, saved settings, slash commands, module init.
local addonName, ns = ...

local PRINT_PREFIX = "|cff9b8cffintroVert|r: "
local HELP_INDENT = "  "
local CORE_HELP = { "/iv help - show this list" }

ns.name = addonName
ns.modules = {}

local eventFrame = CreateFrame("Frame")
local handlers = {}
local commands = {}

function ns.Print(message)
  print(PRINT_PREFIX .. tostring(message))
end

-- True for Midnight "secret" values (unreadable chat during encounters).
function ns.IsSecret(value)
  return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Registers a chat message filter; false when the client has no filter API.
function ns.AddChatFilter(event, filter)
  local add = ChatFrame_AddMessageEventFilter
    or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
  if not add then
    return false
  end
  add(event, filter)
  return true
end

-- "Name-Realm" of the logged-in character; the key for per-character data.
function ns.CharacterKey()
  return ("%s-%s"):format(UnitName("player"), GetRealmName())
end

-- Subscribe to a game event. Errors in one handler never block the others.
function ns.On(event, handler)
  if not handlers[event] then
    handlers[event] = {}
    eventFrame:RegisterEvent(event)
  end
  handlers[event][#handlers[event] + 1] = handler
end

-- Runs fn, reporting (not raising) any error so one failure never blocks others.
local function safeCall(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    geterrorhandler()(err)
  end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  for _, handler in ipairs(handlers[event] or {}) do
    safeCall(handler, event, ...)
  end
end)

-- Addon-internal signals (e.g. "DelveRecorded") so modules can react to each
-- other without depending on each other. Not game events: nothing is
-- registered with the client.
local subscribers = {}

function ns.Subscribe(topic, handler)
  subscribers[topic] = subscribers[topic] or {}
  subscribers[topic][#subscribers[topic] + 1] = handler
end

function ns.Publish(topic, ...)
  for _, handler in ipairs(subscribers[topic] or {}) do
    safeCall(handler, ...)
  end
end

local settingsListeners = {}

-- listener(path) runs after every UpdateSetting (options panel or slash).
function ns.OnSettingsChanged(listener)
  settingsListeners[#settingsListeners + 1] = listener
end

-- Replace the whole settings table (SavedVariables point at the new copy).
function ns.SetSettings(settings)
  IntroVertDB = settings
  ns.db = settings
end

function ns.UpdateSetting(path, value)
  ns.SetSettings(ns.Defaults.with(ns.db, path, value))
  for _, listener in ipairs(settingsListeners) do
    safeCall(listener, path)
  end
end

function ns.RegisterModule(name, module)
  ns.modules[name] = module
end

-- `help` is an optional list of lines shown by /iv help, one per subcommand.
function ns.RegisterCommand(name, handler, help)
  commands[name] = { handler = handler, help = help or {} }
end

local function sortedCommandNames()
  local names = {}
  for name in pairs(commands) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

function ns.PrintHelpLines(lines)
  for _, line in ipairs(lines) do
    ns.Print(HELP_INDENT .. line)
  end
end

local function printHelp()
  ns.Print("Commands:")
  ns.PrintHelpLines(CORE_HELP)
  for _, name in ipairs(sortedCommandNames()) do
    ns.PrintHelpLines(commands[name].help)
  end
end

local function onSlash(input)
  local name, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  name = (name or ""):lower()
  if name == "" or name == "help" then
    printHelp()
    return
  end
  local command = commands[name]
  if not command then
    ns.Print(("Unknown command '%s'. Type /iv help for a list."):format(name))
    return
  end
  command.handler(rest or "")
end

SLASH_INTROVERT1 = "/iv"
SLASH_INTROVERT2 = "/introvert"
SlashCmdList.INTROVERT = onSlash

ns.On("ADDON_LOADED", function(_, loadedName)
  if loadedName ~= addonName then
    return
  end
  ns.SetSettings(ns.Defaults.merge(ns.Defaults.values, IntroVertDB))
  for _, module in pairs(ns.modules) do
    if module.OnInit then
      module.OnInit()
    end
  end
end)
