-- Quiet Groups: calm chat in matchmade dungeons and LFR, polite auto
-- greet/farewell, loud ready-check alarm, and a one-click leave button.
local _, ns = ...

local Profile = ns.QuietProfile
local Filter = ns.QuietFilter
local Phrases = ns.QuietPhrases
local Commands = ns.QuietCommands

local GREET_DELAY_SECONDS = 4
local LOG_LIMIT = 200
local LOG_PRINT_COUNT = 20
local SECRET_PLACEHOLDER = "<unreadable during encounter>"
local LEAVE_BUTTON_WIDTH = 160
local LEAVE_BUTTON_HEIGHT = 32
local LEAVE_BUTTON_OFFSET_Y = -180

local FILTERED_EVENTS = {
  "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
  "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
  "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
}

local LEADER_EVENTS = {
  CHAT_MSG_INSTANCE_CHAT_LEADER = true,
  CHAT_MSG_PARTY_LEADER = true,
  CHAT_MSG_RAID_LEADER = true,
}

local ALARM_TEXT = {
  READY_CHECK = "Ready check!",
  LFG_ROLE_CHECK_SHOW = "Role check!",
  LFG_PROPOSAL_SHOW = "Your group is ready!",
}

local REFRESH_EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE" }

local Quiet = {}

-- State is never edited in place; setState swaps in a patched copy.
local state = {
  profile = false, greeted = false, inEncounter = false, strictUntil = 0,
  hiddenCount = 0, lastLineID = false, lastDecision = false,
}
local hiddenLog = {}
local leaveButton

local function setState(patch)
  local nextState = {}
  for key, value in pairs(state) do
    nextState[key] = value
  end
  for key, value in pairs(patch) do
    nextState[key] = value
  end
  state = nextState
end

local function appendCapped(list, item, limit)
  local result = {}
  for index = math.max(1, #list - limit + 2), #list do
    result[#result + 1] = list[index]
  end
  result[#result + 1] = item
  return result
end

local function settings()
  return ns.db.quiet
end

local function isSecret(value)
  return issecretvalue ~= nil and issecretvalue(value) == true
end

local function sendInstanceChat(text)
  if not text then
    return
  end
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  send(text, "INSTANCE_CHAT")
end

local function readContext()
  local inInstance, instanceType = IsInInstance()
  local _, _, difficultyID = GetInstanceInfo()
  return {
    inInstance = inInstance,
    instanceType = instanceType,
    difficultyID = difficultyID,
    isLFG = IsPartyLFG() == true or (IsInLFGDungeon ~= nil and IsInLFGDungeon() == true),
  }
end

-- Leave button ---------------------------------------------------------------

-- Leaves only the instance (LFG) group, never a home party you queued with.
local function leaveGroup()
  local leave = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
  leave(LE_PARTY_CATEGORY_INSTANCE)
end

local function getLeaveButton()
  if leaveButton then
    return leaveButton
  end
  leaveButton = CreateFrame("Button", "IntroVertLeaveButton", UIParent, "UIPanelButtonTemplate")
  leaveButton:SetSize(LEAVE_BUTTON_WIDTH, LEAVE_BUTTON_HEIGHT)
  leaveButton:SetPoint("TOP", UIParent, "TOP", 0, LEAVE_BUTTON_OFFSET_Y)
  leaveButton:SetText("Leave group")
  leaveButton:SetScript("OnClick", function(self)
    self:Hide()
    leaveGroup()
  end)
  leaveButton:Hide()
  return leaveButton
end

local function hideLeaveButton()
  if leaveButton then
    leaveButton:Hide()
  end
end

-- Activation -----------------------------------------------------------------

local function scheduleGreeting()
  if not settings().greet or state.greeted then
    return
  end
  setState({ greeted = true })
  C_Timer.After(GREET_DELAY_SECONDS, function()
    if state.profile then
      sendInstanceChat(Phrases.pick(settings().greetings, math.random))
    end
  end)
end

local function activate(profile)
  local quiet = settings()
  setState({ profile = profile, hiddenCount = 0 })
  hiddenLog = {}
  ns.Print(("Quiet mode on (%s, chat: %s)."):format(profile, quiet.chatLevel[profile]))
  scheduleGreeting()
end

-- Keeps `greeted` so a ghost run out and back in does not greet twice.
local function deactivate()
  setState({ profile = false, inEncounter = false, strictUntil = 0, lastLineID = false })
  hideLeaveButton()
end

function Quiet.Refresh()
  local ctx = readContext()
  if not ctx.isLFG and state.greeted then
    setState({ greeted = false })
  end
  local profile = Profile.resolve(ctx)
  local active = Profile.isEnabled(profile, settings()) and profile or false
  if active == state.profile then
    return
  end
  if state.profile then
    deactivate()
  end
  if active then
    activate(active)
  end
end

-- Chat filter ----------------------------------------------------------------

-- Needles are rebuilt per line so a late role assignment or edited
-- keywords apply immediately; the lists are tiny.
local function filterOptions()
  local quiet = settings()
  return {
    level = quiet.chatLevel[state.profile],
    needles = Filter.buildNeedles(quiet.keywords, UnitName("player"), UnitGroupRolesAssigned("player")),
    strict = state.inEncounter or GetTime() < state.strictUntil,
  }
end

local function recordHidden(author, text)
  setState({ hiddenCount = state.hiddenCount + 1 })
  hiddenLog = appendCapped(hiddenLog, { time = date("%H:%M:%S"), author = author, text = text }, LOG_LIMIT)
end

local function buildMessage(event, text, author)
  local secret = isSecret(text) or isSecret(author)
  return {
    text = (not secret) and text or nil,
    isSecret = secret,
    isLeader = LEADER_EVENTS[event] == true,
    isSelf = (not secret) and Ambiguate(author, "none") == UnitName("player"),
  }
end

-- WoW calls message filters once per chat window, so the decision for a
-- line is cached by lineID (arg11) to keep the hidden counter accurate.
local function chatFilter(_, event, text, author, ...)
  if not state.profile then
    return false
  end
  local lineID = select(9, ...)
  if isSecret(lineID) then
    lineID = nil
  end
  if lineID and lineID == state.lastLineID then
    return state.lastDecision
  end
  local message = buildMessage(event, text, author)
  local hide = Filter.shouldHide(message, filterOptions())
  if hide then
    local shown = message.isSecret and SECRET_PLACEHOLDER
    recordHidden(shown or author, shown or text)
  end
  setState({ lastLineID = lineID or false, lastDecision = hide })
  return hide
end

local function registerChatFilters()
  local addFilter = ChatFrame_AddMessageEventFilter
    or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
  if not addFilter then
    ns.Print("Chat filter API not found; Quiet chat filtering is disabled.")
    return
  end
  for _, event in ipairs(FILTERED_EVENTS) do
    addFilter(event, chatFilter)
  end
end

-- Event handlers ---------------------------------------------------------------

local function onAlarm(event)
  if not settings().readyAlarm then
    return
  end
  PlaySound(SOUNDKIT.READY_CHECK, "Master")
  if FlashClientIcon then
    FlashClientIcon()
  end
  RaidNotice_AddMessage(RaidWarningFrame, ALARM_TEXT[event], ChatTypeInfo.RAID_WARNING)
end

local function onEncounterStart()
  if state.profile and settings().encounterFocus then
    setState({ inEncounter = true })
  end
end

local function onEncounterEnd(_, _, _, _, _, success)
  local quiet = settings()
  local wipeSeconds = quiet.wipeMuteSeconds
  local wiped = success == 0 and state.profile and quiet.encounterFocus and wipeSeconds > 0
  setState({
    inEncounter = false,
    strictUntil = wiped and (GetTime() + wipeSeconds) or state.strictUntil,
  })
end

local function onCompletion()
  if not state.profile then
    return
  end
  if settings().farewell then
    sendInstanceChat(Phrases.pick(settings().farewells, math.random))
  end
  getLeaveButton():Show()
end

-- Slash commands ---------------------------------------------------------------

local function describeProfile(name)
  local quiet = settings()
  local enabled = quiet.enabled[name] and "on" or "off"
  return ("%s=%s (%s)"):format(name, quiet.chatLevel[name], enabled)
end

local function printStatus()
  local active = state.profile or "inactive"
  ns.Print(("Quiet [%s] | %s | %s | %d hidden"):format(
    active, describeProfile(Profile.DUNGEON), describeProfile(Profile.LFR), state.hiddenCount))
end

local function printLog()
  if #hiddenLog == 0 then
    ns.Print("Nothing hidden this run.")
    return
  end
  for index = math.max(1, #hiddenLog - LOG_PRINT_COUNT + 1), #hiddenLog do
    local entry = hiddenLog[index]
    ns.Print(("[%s] %s: %s"):format(entry.time, tostring(entry.author), tostring(entry.text)))
  end
end

local HELP_LINES = {
  "/iv quiet - show Quiet status and hidden count",
  "/iv quiet on | off - enable or disable Quiet mode",
  "/iv quiet dungeon <level> - chat level in dungeons",
  "/iv quiet lfr <level> - chat level in Raid Finder",
  "/iv quiet log - show the last 20 hidden lines",
  "    levels: " .. Filter.LEVEL_LIST,
}

local function printHelp()
  ns.PrintHelpLines(HELP_LINES)
end

local function setEnabled(command)
  for _, name in ipairs(Profile.ALL) do
    ns.UpdateSetting({ "quiet", "enabled", name }, command.value)
  end
  ns.Print(command.value and "Quiet mode enabled." or "Quiet mode disabled.")
end

local function setLevel(command)
  ns.UpdateSetting({ "quiet", "chatLevel", command.profile }, command.value)
  ns.Print(("%s chat level set to %s."):format(command.profile, command.value))
end

local ACTIONS = {
  status = printStatus,
  log = printLog,
  help = printHelp,
  enable = setEnabled,
  level = setLevel,
  error = function(command) ns.Print(command.message) end,
}

local function onCommand(input)
  local command = Commands.parse(input)
  ACTIONS[command.action](command)
end

-- Init -------------------------------------------------------------------------

function Quiet.OnInit()
  registerChatFilters()
  ns.OnSettingsChanged(Quiet.Refresh)
  for _, event in ipairs(REFRESH_EVENTS) do
    ns.On(event, Quiet.Refresh)
  end
  for event in pairs(ALARM_TEXT) do
    ns.On(event, onAlarm)
  end
  ns.On("ENCOUNTER_START", onEncounterStart)
  ns.On("ENCOUNTER_END", onEncounterEnd)
  ns.On("LFG_COMPLETION_REWARD", onCompletion)
end

ns.RegisterCommand("quiet", onCommand, HELP_LINES)
ns.RegisterModule("quiet", Quiet)
