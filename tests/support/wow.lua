-- Minimal fake of the WoW client API, enough to drive the addon from tests.
-- install() sets globals and returns an `env` used to fire events and inspect
-- side effects; uninstall() restores whatever globals existed before.
local Wow = {}

local STUBBED_GLOBALS = {
  "CreateFrame", "UIParent", "print", "geterrorhandler", "SlashCmdList",
  "SLASH_INTROVERT1", "SLASH_INTROVERT2", "IntroVertDB",
  "IsInInstance", "GetInstanceInfo", "IsPartyLFG", "UnitName",
  "UnitGroupRolesAssigned", "Ambiguate", "C_ChatInfo", "C_Timer",
  "C_PartyInfo", "GetTime", "PlaySound", "SOUNDKIT", "FlashClientIcon",
  "RaidNotice_AddMessage", "RaidWarningFrame", "ChatTypeInfo",
  "ChatFrame_AddMessageEventFilter", "issecretvalue", "date",
  "LE_PARTY_CATEGORY_INSTANCE",
}

local saved = {}

local function newEnv()
  return {
    eventFrames = {}, sent = {}, sounds = {}, notices = {}, prints = {},
    timers = {}, filters = {}, errors = {}, buttons = {}, flashes = 0, leaves = 0,
    instance = { inInstance = false, instanceType = "none", difficultyID = 0 },
    isLFG = false, playerName = "Nubbel", role = "DAMAGER", now = 100,
    secret = false,
  }
end

local function newFrame(env, kind)
  local frame = { scripts = {}, shown = true, kind = kind }
  function frame:RegisterEvent(event) env.eventFrames[event] = self end
  function frame:SetScript(name, fn) self.scripts[name] = fn end
  function frame:SetSize() end
  function frame:SetPoint() end
  function frame:SetText(text) self.text = text end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:IsShown() return self.shown end
  function frame:Click() self.scripts.OnClick(self) end
  if kind == "Button" then
    env.buttons[#env.buttons + 1] = frame
  end
  return frame
end

local function installUi(env)
  _G.CreateFrame = function(kind) return newFrame(env, kind) end
  _G.UIParent = newFrame(env, "Frame")
  _G.print = function(message) env.prints[#env.prints + 1] = message end
  _G.geterrorhandler = function()
    return function(err) env.errors[#env.errors + 1] = err end
  end
  _G.SlashCmdList = {}
  _G.PlaySound = function(id, channel) env.sounds[#env.sounds + 1] = { id = id, channel = channel } end
  _G.SOUNDKIT = { READY_CHECK = 8960 }
  _G.FlashClientIcon = function() env.flashes = env.flashes + 1 end
  _G.RaidWarningFrame = {}
  _G.ChatTypeInfo = { RAID_WARNING = {} }
  _G.RaidNotice_AddMessage = function(_, text) env.notices[#env.notices + 1] = text end
  _G.date = os.date
end

local function installGame(env)
  _G.IsInInstance = function() return env.instance.inInstance, env.instance.instanceType end
  _G.GetInstanceInfo = function()
    return "Test", env.instance.instanceType, env.instance.difficultyID
  end
  _G.IsPartyLFG = function() return env.isLFG end
  _G.UnitName = function() return env.playerName end
  _G.UnitGroupRolesAssigned = function() return env.role end
  _G.Ambiguate = function(name) return (name:gsub("%-.*$", "")) end
  _G.GetTime = function() return env.now end
  _G.issecretvalue = function() return env.secret end
  _G.C_ChatInfo = {
    SendChatMessage = function(text, channel) env.sent[#env.sent + 1] = { text = text, channel = channel } end,
  }
  _G.C_Timer = { After = function(_, fn) env.timers[#env.timers + 1] = fn end }
  _G.LE_PARTY_CATEGORY_INSTANCE = 2
  _G.C_PartyInfo = {
    LeaveParty = function(category)
      env.leaves = env.leaves + 1
      env.leftCategory = category
    end,
  }
  _G.ChatFrame_AddMessageEventFilter = function(event, fn)
    env.filters[event] = env.filters[event] or {}
    table.insert(env.filters[event], fn)
  end
end

local function addHelpers(env)
  function env.fire(event, ...)
    local frame = assert(env.eventFrames[event], "no handler registered for " .. event)
    frame.scripts.OnEvent(frame, event, ...)
  end

  function env.runTimers()
    local pending = env.timers
    env.timers = {}
    for _, fn in ipairs(pending) do fn() end
  end

  -- Simulates one chat line delivered to `frames` chat windows.
  -- Returns true when any filter hid it.
  function env.chat(event, text, author, lineID, frames)
    local hidden = false
    for _ = 1, frames or 1 do
      for _, fn in ipairs(env.filters[event] or {}) do
        hidden = fn({}, event, text, author, "", "", "", "", 0, 0, "", 0, lineID) or hidden
      end
    end
    return hidden
  end

  function env.slash(input)
    _G.SlashCmdList.INTROVERT(input)
  end

  function env.lastPrint()
    return env.prints[#env.prints]
  end

  -- True when any printed line contains `text` (plain match, not a pattern).
  function env.printed(text)
    for _, line in ipairs(env.prints) do
      if line:find(text, 1, true) then
        return true
      end
    end
    return false
  end
end

function Wow.install()
  for _, name in ipairs(STUBBED_GLOBALS) do
    saved[name] = { value = _G[name] }
  end
  local env = newEnv()
  installUi(env)
  installGame(env)
  addHelpers(env)
  return env
end

function Wow.uninstall()
  for _, name in ipairs(STUBBED_GLOBALS) do
    _G[name] = saved[name] and saved[name].value
  end
  saved = {}
end

-- Loads every file listed in the .toc, in order, into a fresh namespace.
function Wow.loadAddon(helper)
  local ns = {}
  for line in io.lines("IntroVert.toc") do
    local path = line:match("^%s*([^#%s].-)%s*$")
    if path then
      helper.load(path, ns)
    end
  end
  return ns
end

return Wow
