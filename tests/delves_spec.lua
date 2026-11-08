local helper = require("tests.helper")

local NOW = 1000000

describe("Delves", function()
  local Delves

  before_each(function()
    Delves = helper.loadPure({ "Modules/Delves/Delves.lua" }).Delves
  end)

  describe("parseTier", function()
    it("reads the number from the difficulty name", function()
      assert.equal(8, Delves.parseTier("Tier 8"))
      assert.equal(11, Delves.parseTier("Stufe 11"))
    end)

    it("returns nil when there is no number", function()
      assert.is_nil(Delves.parseTier("Story"))
      assert.is_nil(Delves.parseTier(nil))
    end)
  end)

  describe("record", function()
    it("adds a first run", function()
      local result = Delves.record({}, "Fungal Folly", 8, NOW)

      assert.same({ ["Fungal Folly"] = { runs = 1, bestTier = 8, lastAt = NOW } }, result)
    end)

    it("keeps the best tier and counts runs", function()
      local history = { ["Fungal Folly"] = { runs = 1, bestTier = 8, lastAt = 1 } }

      local result = Delves.record(history, "Fungal Folly", 5, NOW)

      assert.same({ runs = 2, bestTier = 8, lastAt = NOW }, result["Fungal Folly"])
    end)

    it("stores tier 0 when the tier is unknown", function()
      assert.equal(0, Delves.record(nil, "Story", nil, NOW)["Story"].bestTier)
    end)

    it("does not change the input", function()
      local history = { ["A"] = { runs = 1, bestTier = 2, lastAt = 1 } }

      Delves.record(history, "A", 9, NOW)

      assert.same({ ["A"] = { runs = 1, bestTier = 2, lastAt = 1 } }, history)
    end)
  end)

  describe("vaultLines", function()
    it("shows finished and open slots in order", function()
      local activities = {
        { index = 2, threshold = 4, progress = 3, level = 0 },
        { index = 1, threshold = 2, progress = 3, level = 8 },
      }

      assert.same({
        "  Slot 1: done (2/2), level 8",
        "  Slot 2: 3/4, 1 more",
      }, Delves.vaultLines(activities))
    end)

    it("leaves out the level when it is zero", function()
      local lines = Delves.vaultLines({ { index = 1, threshold = 1, progress = 1, level = 0 } })

      assert.equal("  Slot 1: done (1/1)", lines[1])
    end)

    it("explains when there is no vault data", function()
      assert.same({ "  No vault data yet." }, Delves.vaultLines({}))
      assert.same({ "  No vault data yet." }, Delves.vaultLines(nil))
    end)
  end)

  describe("bountifulLines", function()
    it("lists delves alphabetically with their zone", function()
      local lines = Delves.bountifulLines({
        { name = "The Waterworks", zone = "The Ringing Deeps" },
        { name = "Fungal Folly", zone = "Isle of Dorn" },
      })

      assert.same({ "  Fungal Folly (Isle of Dorn)", "  The Waterworks (The Ringing Deeps)" }, lines)
    end)

    it("explains when none are found", function()
      assert.same({ "  None found right now." }, Delves.bountifulLines({}))
    end)
  end)

  describe("historyLines", function()
    it("lists delves with best tier and runs", function()
      local lines = Delves.historyLines({
        ["Zekvir's Lair"] = { runs = 1, bestTier = 0, lastAt = 1 },
        ["Fungal Folly"] = { runs = 5, bestTier = 8, lastAt = 1 },
      })

      assert.same({
        "  Fungal Folly - best tier 8, 5 runs",
        "  Zekvir's Lair - best tier ?, 1 run",
      }, lines)
    end)

    it("explains when nothing is recorded", function()
      assert.same({ "  No delves recorded yet. Finish a delve to start." }, Delves.historyLines({}))
    end)

    it("shows chambers and best visit for the Labyrinth", function()
      local lines = Delves.historyLines({
        ["The Labyrinth of Kindo'jan"] = { labyrinth = true, chambers = 14, bestTier = 8, bestVisit = 9, lastAt = 1 },
      })

      assert.same({ "  The Labyrinth of Kindo'jan - best tier 8, 14 chambers, best visit 9/9" }, lines)
    end)
  end)

  describe("recordLabyrinth", function()
    local NAME = "The Labyrinth of Kindo'jan"

    it("records the first chamber", function()
      local result = Delves.recordLabyrinth({}, NAME, 1, 1, NOW)

      assert.same({ labyrinth = true, chambers = 1, bestTier = 1, bestVisit = 1, lastAt = NOW }, result[NAME])
    end)

    it("adds chambers and keeps the best tier and best visit", function()
      local history = { [NAME] = { labyrinth = true, chambers = 10, bestTier = 8, bestVisit = 9, lastAt = 1 } }

      local result = Delves.recordLabyrinth(history, NAME, 3, 2, NOW)

      assert.same({ labyrinth = true, chambers = 11, bestTier = 8, bestVisit = 9, lastAt = NOW }, result[NAME])
    end)

    it("turns an old run-counted entry into chambers", function()
      local history = { [NAME] = { runs = 1, bestTier = 1, lastAt = 1 } }

      local result = Delves.recordLabyrinth(history, NAME, 1, 2, NOW)

      assert.same({ labyrinth = true, chambers = 2, bestTier = 1, bestVisit = 2, lastAt = NOW }, result[NAME])
    end)

    it("does not change the input", function()
      local history = { [NAME] = { labyrinth = true, chambers = 1, bestTier = 1, bestVisit = 1, lastAt = 1 } }

      Delves.recordLabyrinth(history, NAME, 5, 2, NOW)

      assert.equal(1, history[NAME].chambers)
    end)
  end)

  describe("lines", function()
    it("puts each section under its header", function()
      local lines = Delves.lines({ "  v" }, { "  b" }, { "  h" })

      assert.same({
        "This week (Great Vault, world activities)", "  v",
        "Bountiful delves today", "  b",
        "Your delves", "  h",
      }, lines)
    end)
  end)
end)
