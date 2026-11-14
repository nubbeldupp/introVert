-- Auto-away reply: while the game flags you as AFK, everyone who whispers
-- gets one friendly reply per away period (optional, off by default). When
-- you are back, one chat line lists who whispered.
local _, ns = ...

local Away = ns.Away
local Spam = ns.Spam
local Phrases = ns.QuietPhrases

local GM_FLAG = "GM"
local REPLIES_PROMPT = "One of these is whispered while you are away (separate with ;):"

local Tracker = {}

-- nil while at the keyboard; the current away period otherwise.
local state = nil

local function settings()
  return ns.db.shields
end

local function isReadable(...)
  for index = 1, select("#", ...) do
    if ns.IsSecret((select(index, ...))) then
      return false
    end
  end
  return true
end

-- Sending can be blocked by the client (e.g. restricted inside instances);
-- the whisper is still recorded for the summary.
local function sendReply(send)
  local text = Phrases.pick(settings().awayReplies, math.random)
  if not text then
    return
  end
  local ok, err = pcall(send, text)
  if not ok then
    ns.Print("Could not send the away reply: " .. tostring(err))
  end
end

local function onWhisper(sender, send)
  state = Away.addWhisper(state, sender)
  if settings().awayReply and Away.needsReply(state, sender) then
    state = Away.markReplied(state, sender)
    sendReply(send)
  end
end

local function onCharacterWhisper(_, text, author, _, _, _, flags)
  if not state or not isReadable(text, author) or flags == GM_FLAG or Spam.isRecruitment(text) then
    return
  end
  local chatSend = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  onWhisper(author, function(reply) chatSend(reply, "WHISPER", nil, author) end)
end

local function onBattleNetWhisper(_, text, author, ...)
  local bnSenderID = select(11, ...)
  if not state or not isReadable(text, author, bnSenderID) then
    return
  end
  onWhisper(author, function(reply) BNSendWhisper(bnSenderID, reply) end)
end

local function onFlagsChanged(_, unit)
  if unit ~= "player" then
    return
  end
  local afk = UnitIsAFK("player") == true
  if afk and not state then
    state = Away.start(time())
  elseif not afk and state then
    local summary = Away.summary(state, time())
    state = nil
    if summary then
      ns.Print(summary)
    end
  end
end

ns.Options.AddSection(function(ui)
  ui.header("Away")
  ui.checkbox({ "shields", "awayReply" }, "Reply to whispers while away",
    "While you are AFK, everyone who whispers gets one friendly reply. When you are back, introVert lists who whispered.")
  ui.button("Away replies", "Edit", function()
    ns.Options.EditList({ "shields", "awayReplies" }, REPLIES_PROMPT, ns.Lists.SENTENCES)
  end, REPLIES_PROMPT)
end)

function Tracker.OnInit()
  ns.On("PLAYER_FLAGS_CHANGED", onFlagsChanged)
  ns.On("CHAT_MSG_WHISPER", onCharacterWhisper)
  ns.On("CHAT_MSG_BN_WHISPER", onBattleNetWhisper)
end

ns.RegisterModule("awayReply", Tracker)
