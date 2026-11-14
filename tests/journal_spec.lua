local helper = require("tests.helper")

local HOUR = 3600
local NOW = 1000000
local GOLD = 10000

describe("Journal", function()
  local Journal

  before_each(function()
    Journal = helper.loadPure({
      "Modules/Raids/Lockouts.lua",
      "Modules/Alts/Alts.lua",
      "Modules/Journal/Journal.lua",
    }).Journal
  end)

  local function session(character, startedAt, gold)
    return Journal.newSession(character, startedAt or NOW, gold or 0)
  end

  describe("newSession", function()
    it("starts empty with the current gold", function()
      assert.same({
        character = "Abe-Realm", startedAt = NOW, updatedAt = NOW, startGold = 5, gold = 5,
        counts = {}, entries = {},
      }, Journal.newSession("Abe-Realm", NOW, 5))
    end)
  end)

  describe("addEntry", function()
    it("counts the kind, logs the text and returns a new session", function()
      local original = session("Abe-Realm")

      local updated = Journal.addEntry(original, "boss", "Boss: Onyxia", NOW + 60)

      assert.same({ boss = 1 }, updated.counts)
      assert.same({ { at = NOW + 60, kind = "boss", text = "Boss: Onyxia" } }, updated.entries)
      assert.equal(NOW + 60, updated.updatedAt)
      assert.same({}, original.counts)
      assert.same({}, original.entries)
    end)

    it("keeps only the newest entries", function()
      local current = session("Abe-Realm")
      for index = 1, Journal.MAX_ENTRIES + 2 do
        current = Journal.addEntry(current, "delve", "Delve " .. index, NOW + index)
      end

      assert.equal(Journal.MAX_ENTRIES, #current.entries)
      assert.equal("Delve 3", current.entries[1].text)
      assert.equal(Journal.MAX_ENTRIES + 2, current.counts.delve)
    end)
  end)

  describe("withGold and touch", function()
    it("return new sessions with the new gold or time", function()
      local original = session("Abe-Realm", NOW, 100)

      assert.equal(500, Journal.withGold(original, 500, NOW + 1).gold)
      assert.equal(NOW + 9, Journal.touch(original, NOW + 9).updatedAt)
      assert.equal(100, original.gold)
      assert.equal(NOW, original.updatedAt)
    end)
  end)

  describe("session list", function()
    it("puts a new session first and keeps only the newest ones", function()
      local sessions = {}
      for index = 1, Journal.MAX_SESSIONS + 1 do
        sessions = Journal.startSession(sessions, session("Abe-Realm", NOW + index))
      end

      assert.equal(Journal.MAX_SESSIONS, #sessions)
      assert.equal(NOW + Journal.MAX_SESSIONS + 1, sessions[1].startedAt)
    end)

    it("finds and replaces the newest session of a character", function()
      local sessions = Journal.startSession({}, session("Abe-Realm", NOW))
      sessions = Journal.startSession(sessions, session("Bob-Realm", NOW + 1))
      sessions = Journal.startSession(sessions, session("Abe-Realm", NOW + 2))

      assert.equal(1, Journal.currentIndex(sessions, "Abe-Realm"))
      assert.equal(2, Journal.currentIndex(sessions, "Bob-Realm"))
      assert.is_nil(Journal.currentIndex(sessions, "Cid-Realm"))

      local replaced = Journal.replaceAt(sessions, 2, Journal.touch(sessions[2], NOW + 50))
      assert.equal(NOW + 50, replaced[2].updatedAt)
      assert.equal(NOW + 1, sessions[2].updatedAt)
    end)
  end)

  describe("summary", function()
    it("lists counts in a fixed order with singular and plural, then the gold change", function()
      local current = session("Abe-Realm", NOW, 0)
      current = Journal.addEntry(current, "achievement", "A", NOW)
      current = Journal.addEntry(current, "boss", "B", NOW)
      current = Journal.addEntry(current, "boss", "B", NOW)
      current = Journal.addEntry(current, "attempt", "C", NOW)
      current = Journal.withGold(current, 1234 * GOLD, NOW)

      assert.equal("2 boss kills, 1 achievement, 1 mount attempt, +1,234g", Journal.summary(current))
    end)

    it("shows gold losses and ignores changes under 1g", function()
      assert.equal("-50g", Journal.summary(Journal.withGold(session("A-R", NOW, 100 * GOLD), 50 * GOLD, NOW)))
      assert.is_nil(Journal.summary(Journal.withGold(session("A-R", NOW, 0), GOLD - 1, NOW)))
    end)

    it("covers delves and Labyrinth chambers", function()
      local current = Journal.addEntry(session("A-R"), "delve", "D", NOW)
      current = Journal.addEntry(current, "chamber", "C", NOW)
      current = Journal.addEntry(current, "chamber", "C", NOW)

      assert.equal("1 delve, 2 Labyrinth chambers", Journal.summary(current))
    end)
  end)

  describe("lines", function()
    local clock = {
      time = function(at) return ("t%d"):format(at - NOW) end,
      day = function(at) return ("d%d"):format(at - NOW) end,
    }

    it("shows this session newest first, then earlier sessions", function()
      local earlier = Journal.withGold(session("Bob-Realm", NOW - 2 * HOUR, 0), 300 * GOLD, NOW - HOUR)
      local current = Journal.addEntry(session("Abe-Realm", NOW, 0), "delve", "Delve: Fungal Folly, tier 8", NOW + 60)
      current = Journal.addEntry(current, "boss", "Boss: Onyxia (Onyxia's Lair)", NOW + 120)
      local quiet = session("Cid-Realm", NOW - 5 * HOUR, 0)
      local sessions = Journal.startSession(Journal.startSession(Journal.startSession({}, quiet), earlier), current)

      assert.same({
        "This session: Abe-Realm, 20m",
        "  1 boss kill, 1 delve",
        "  t120  Boss: Onyxia (Onyxia's Lair)",
        "  t60  Delve: Fungal Folly, tier 8",
        "Earlier sessions",
        "  d-7200  Bob-Realm, 1h 0m - +300g",
        "  d-18000  Cid-Realm, 1m - quiet session",
      }, Journal.lines(sessions, "Abe-Realm", NOW + 20 * 60, clock))
    end)

    it("says when this session has nothing yet and there are no earlier ones", function()
      local sessions = Journal.startSession({}, session("Abe-Realm", NOW))

      assert.same({
        "This session: Abe-Realm, 1m",
        "  Nothing yet. Have a good one!",
      }, Journal.lines(sessions, "Abe-Realm", NOW, clock))
    end)

    it("explains when no session was recorded yet", function()
      assert.same({ "No session recorded yet. It starts with your next login." },
        Journal.lines({}, "Abe-Realm", NOW, clock))
    end)
  end)
end)
