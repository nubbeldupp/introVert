-- Do Not Disturb: declines guild invites, duels, pet battle duels and group
-- invites from strangers, and hides guild recruitment spam in chat.
local _, ns = ...

local Spam = ns.Spam
local Phrases = ns.QuietPhrases

local LOG_LIMIT = 100
local LOG_PRINT_COUNT = 20
local SPAM_EVENTS = { "CHAT_MSG_CHANNEL", "CHAT_MSG_WHISPER", "CHAT_MSG_SAY", "CHAT_MSG_YELL" }
local SWITCHES = { "guildInvites", "duels", "petDuels", "groupInvites", "spam" }
local REPLIES_PROMPT = "One of these is whispered when you decline (comma separated):"
local HELP_LINES = {
  "/iv dnd - what Do Not Disturb declined and hid this session",
  "/iv dnd log - the last 20 declined invites and hidden messages",
  "/iv dnd on | off - switch all Do Not Disturb shields",
}

local Shields = {}

-- Session-only bookkeeping; replaced, never edited in place.
local counts = { guild = 0, duel = 0, petDuel = 0, group = 0, spam = 0 }
local log = {}
local lastLineID, lastDecision = false, false

local function settings()
  return ns.db.shields
end

local function record(kind, text)
  local nextCounts = {}
  for key, value in pairs(counts) do
    nextCounts[key] = value
  end
  nextCounts[kind] = nextCounts[kind] + 1
  counts = nextCounts
  log = ns.Lists.appendCapped(log, ("[%s] %s"):format(date("%H:%M"), text), LOG_LIMIT)
end

local function politeReply(name)
  if not settings().reply or not name then
    return
  end
  local text = Phrases.pick(settings().replies, math.random)
  if not text then
    return
  end
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  send(text, "WHISPER", nil, name)
end

local function decline(kind, cancel, popup, message, name)
  cancel()
  StaticPopup_Hide(popup)
  record(kind, message)
  ns.Print(message)
  politeReply(name)
end

local function isFriend(guid)
  if not guid then
    return false
  end
  local ok, friend = pcall(function()
    return C_FriendList.IsFriend(guid) or C_BattleNet.GetAccountInfoByGUID(guid) ~= nil
  end)
  return ok and friend == true
end

-- Event handlers -----------------------------------------------------------------

local function onGuildInvite(_, inviter, guildName)
  if settings().guildInvites then
    local message = ("Declined guild invite from %s (%s)."):format(inviter, guildName or "?")
    decline("guild", DeclineGuild, "GUILD_INVITE", message, inviter)
  end
end

local function onDuel(_, name)
  if settings().duels then
    decline("duel", CancelDuel, "DUEL_REQUESTED", ("Declined duel from %s."):format(name), name)
  end
end

local function onPetDuel(_, name)
  if settings().petDuels then
    local message = ("Declined pet battle duel from %s."):format(name)
    decline("petDuel", C_PetBattles.CancelPVPDuel, "PET_BATTLE_PVP_DUEL_REQUESTED", message, name)
  end
end

local function onGroupInvite(_, name, _, _, _, _, _, inviterGUID)
  if settings().groupInvites and not isFriend(inviterGUID) then
    decline("group", DeclineGroup, "PARTY_INVITE", ("Declined group invite from %s."):format(name), name)
  end
end

-- Chat windows call filters once each, so decisions are cached by lineID.
local function spamFilter(_, _, text, author, ...)
  if not settings().spam then
    return false
  end
  local lineID = select(9, ...)
  if ns.IsSecret(lineID) then
    lineID = nil
  end
  if lineID and lineID == lastLineID then
    return lastDecision
  end
  local hide = not ns.IsSecret(text) and Spam.isRecruitment(text)
  if hide then
    record("spam", ("Hid %s: %s"):format(tostring(author), text))
  end
  lastLineID, lastDecision = lineID or false, hide
  return hide
end

-- Slash commands ---------------------------------------------------------------

local function printStatus()
  ns.Print(("This session: declined %d guild invites, %d duels, %d pet battle duels, %d group invites; hid %d recruitment messages."):format(
    counts.guild, counts.duel, counts.petDuel, counts.group, counts.spam))
end

local function printLog()
  if #log == 0 then
    ns.Print("Nothing declined or hidden this session.")
    return
  end
  for index = math.max(1, #log - LOG_PRINT_COUNT + 1), #log do
    ns.Print(log[index])
  end
end

local function setAll(enabled)
  for _, key in ipairs(SWITCHES) do
    ns.UpdateSetting({ "shields", key }, enabled)
  end
  ns.Print(enabled and "Do Not Disturb on." or "Do Not Disturb off.")
end

local function onCommand(input)
  local subcommand = input:match("^%s*(%S*)"):lower()
  if subcommand == "" then
    printStatus()
  elseif subcommand == "log" then
    printLog()
  elseif subcommand == "on" or subcommand == "off" then
    setAll(subcommand == "on")
  else
    ns.PrintHelpLines(HELP_LINES)
  end
end

-- Options ------------------------------------------------------------------------

local function shield(key)
  return { "shields", key }
end

ns.Options.AddSection(function(ui)
  ui.header("Do Not Disturb")
  ui.checkbox(shield("guildInvites"), "Decline guild invites", "Automatically decline every guild invite.")
  ui.checkbox(shield("duels"), "Decline duels", "Automatically decline duel requests.")
  ui.checkbox(shield("petDuels"), "Decline pet battle duels", "Automatically decline pet battle duel requests.")
  ui.checkbox(shield("groupInvites"), "Decline group invites from strangers",
    "Friends and Battle.net friends can still invite you.")
  ui.checkbox(shield("spam"), "Hide guild recruitment spam",
    "Hides recruitment in General, Trade, Services, say/yell and whispers (English and German).")
  ui.checkbox(shield("reply"), "Send a polite reply", "Whisper one of your polite replies when declining.")
  ui.button("Polite replies", "Edit", function()
    ns.Options.EditList(shield("replies"), REPLIES_PROMPT)
  end, REPLIES_PROMPT)
end)

function Shields.OnInit()
  ns.On("GUILD_INVITE_REQUEST", onGuildInvite)
  ns.On("DUEL_REQUESTED", onDuel)
  ns.On("PET_BATTLE_PVP_DUEL_REQUESTED", onPetDuel)
  ns.On("PARTY_INVITE_REQUEST", onGroupInvite)
  for _, event in ipairs(SPAM_EVENTS) do
    if not ns.AddChatFilter(event, spamFilter) then
      return
    end
  end
end

ns.RegisterCommand("dnd", onCommand, HELP_LINES)
ns.RegisterModule("shields", Shields)
