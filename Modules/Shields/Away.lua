-- Pure bookkeeping for one away (AFK) period: who whispered, who already got
-- the away reply, and the summary shown on return. Every helper returns a
-- new state; nothing is changed in place.
local _, ns = ...

local Away = {}

local function copyList(list)
  local copy = {}
  for index, value in ipairs(list) do
    copy[index] = value
  end
  return copy
end

local function copySet(set)
  local copy = {}
  for key, value in pairs(set) do
    copy[key] = value
  end
  return copy
end

local function withChanges(state, changes)
  local changed = {
    since = state.since,
    count = state.count,
    senders = state.senders,
    replied = state.replied,
  }
  for key, value in pairs(changes) do
    changed[key] = value
  end
  return changed
end

function Away.start(now)
  return { since = now, count = 0, senders = {}, replied = {} }
end

local function hasSender(senders, sender)
  for _, known in ipairs(senders) do
    if known == sender then
      return true
    end
  end
  return false
end

function Away.addWhisper(state, sender)
  local senders = state.senders
  if not hasSender(senders, sender) then
    senders = copyList(senders)
    senders[#senders + 1] = sender
  end
  return withChanges(state, { count = state.count + 1, senders = senders })
end

function Away.needsReply(state, sender)
  return not state.replied[sender]
end

function Away.markReplied(state, sender)
  local replied = copySet(state.replied)
  replied[sender] = true
  return withChanges(state, { replied = replied })
end

-- "While you were away (12m): 2 whispers from Anna, Bob." or nil when
-- nobody whispered.
function Away.summary(state, now)
  if state.count == 0 then
    return nil
  end
  return ("While you were away (%s): %d %s from %s."):format(
    ns.RaidLockouts.formatDuration(now - state.since),
    state.count,
    state.count == 1 and "whisper" or "whispers",
    table.concat(state.senders, ", "))
end

ns.Away = Away
