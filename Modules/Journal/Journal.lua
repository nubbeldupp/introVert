-- Session journal logic: sessions, entries, summaries and display lines.
-- Pure: times, gold and the clock formatter are passed in, and every
-- function returns new tables. Reuses ns.Alts.formatGold and
-- ns.RaidLockouts.formatDuration.
local _, ns = ...

local Journal = {}

Journal.MAX_SESSIONS = 30
Journal.MAX_ENTRIES = 100
Journal.EARLIER_LIMIT = 10

local INDENT = "  "
local COPPER_PER_GOLD = 10000
local NOTHING_YET = "Nothing yet. Have a good one!"
local NO_SESSION = "No session recorded yet. It starts with your next login."

-- Summary order with singular and plural labels.
local KINDS = {
  { kind = "boss", one = "boss kill", many = "boss kills" },
  { kind = "delve", one = "delve", many = "delves" },
  { kind = "chamber", one = "Labyrinth chamber", many = "Labyrinth chambers" },
  { kind = "achievement", one = "achievement", many = "achievements" },
  { kind = "attempt", one = "mount attempt", many = "mount attempts" },
}

local function copy(tbl)
  local result = {}
  for key, value in pairs(tbl) do
    result[key] = value
  end
  return result
end

function Journal.newSession(character, now, gold)
  return {
    character = character, startedAt = now, updatedAt = now,
    startGold = gold, gold = gold, counts = {}, entries = {},
  }
end

-- Counts `kind` and logs `text`; only the newest MAX_ENTRIES lines are kept.
function Journal.addEntry(session, kind, text, now)
  local counts = copy(session.counts)
  counts[kind] = (counts[kind] or 0) + 1
  local entries = {}
  local first = math.max(1, #session.entries + 2 - Journal.MAX_ENTRIES)
  for index = first, #session.entries do
    entries[#entries + 1] = session.entries[index]
  end
  entries[#entries + 1] = { at = now, kind = kind, text = text }
  local updated = copy(session)
  updated.counts, updated.entries, updated.updatedAt = counts, entries, now
  return updated
end

function Journal.withGold(session, gold, now)
  local updated = copy(session)
  updated.gold, updated.updatedAt = gold, now
  return updated
end

function Journal.touch(session, now)
  local updated = copy(session)
  updated.updatedAt = now
  return updated
end

-- Session lists are newest first.
function Journal.startSession(sessions, session)
  local result = { session }
  for index = 1, math.min(#sessions, Journal.MAX_SESSIONS - 1) do
    result[#result + 1] = sessions[index]
  end
  return result
end

function Journal.currentIndex(sessions, character)
  for index, session in ipairs(sessions) do
    if session.character == character then
      return index
    end
  end
  return nil
end

function Journal.replaceAt(sessions, index, session)
  local result = copy(sessions)
  result[index] = session
  return result
end

local function goldText(session)
  local diff = (session.gold or 0) - (session.startGold or 0)
  if math.abs(diff) < COPPER_PER_GOLD then
    return nil
  end
  return (diff > 0 and "+" or "-") .. ns.Alts.formatGold(math.abs(diff))
end

-- "2 boss kills, 1 delve, +300g", or nil for a session with nothing in it.
function Journal.summary(session)
  local parts = {}
  for _, label in ipairs(KINDS) do
    local count = session.counts[label.kind] or 0
    if count > 0 then
      parts[#parts + 1] = ("%d %s"):format(count, count == 1 and label.one or label.many)
    end
  end
  parts[#parts + 1] = goldText(session)
  return #parts > 0 and table.concat(parts, ", ") or nil
end

local function appendCurrent(lines, session, now, clock)
  local duration = ns.RaidLockouts.formatDuration(now - session.startedAt)
  lines[#lines + 1] = ("This session: %s, %s"):format(session.character, duration)
  lines[#lines + 1] = INDENT .. (Journal.summary(session) or NOTHING_YET)
  for index = #session.entries, 1, -1 do
    local entry = session.entries[index]
    lines[#lines + 1] = ("%s%s  %s"):format(INDENT, clock.time(entry.at), entry.text)
  end
end

local function earlierLine(session, clock)
  local duration = ns.RaidLockouts.formatDuration(session.updatedAt - session.startedAt)
  return ("%s%s  %s, %s - %s"):format(INDENT, clock.day(session.startedAt), session.character, duration,
    Journal.summary(session) or "quiet session")
end

-- clock: { time(at) -> "14:02", day(at) -> "Nov 12 18:30" }.
function Journal.lines(sessions, character, now, clock)
  if #sessions == 0 then
    return { NO_SESSION }
  end
  local lines = {}
  local currentIndex = Journal.currentIndex(sessions, character)
  if currentIndex then
    appendCurrent(lines, sessions[currentIndex], now, clock)
  end
  local shown = 0
  for index, session in ipairs(sessions) do
    if index ~= currentIndex and shown < Journal.EARLIER_LIMIT then
      if shown == 0 then
        lines[#lines + 1] = "Earlier sessions"
      end
      lines[#lines + 1] = earlierLine(session, clock)
      shown = shown + 1
    end
  end
  return lines
end

ns.Journal = Journal
