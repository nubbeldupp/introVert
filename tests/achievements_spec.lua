local helper = require("tests.helper")

describe("Achievements", function()
  local Achievements

  before_each(function()
    Achievements = helper.loadPure({ "Modules/Achievements/Achievements.lua" }).Achievements
  end)

  local function entry(name, fraction, overrides)
    local base = { name = name, done = 0, total = 10, fraction = fraction }
    for key, value in pairs(overrides or {}) do
      base[key] = value
    end
    return base
  end

  describe("progress", function()
    it("counts completed criteria", function()
      local result = Achievements.progress({
        { completed = true }, { completed = true }, { completed = false }, { completed = false },
      })

      assert.same({ done = 2, total = 4, fraction = 0.5 }, result)
    end)

    it("uses the counter of a single counting criterion", function()
      local result = Achievements.progress({ { completed = false, quantity = 30, required = 100 } })

      assert.same({ done = 30, total = 100, fraction = 0.3 }, result)
    end)

    it("caps an over-full counter", function()
      local result = Achievements.progress({ { completed = false, quantity = 120, required = 100 } })

      assert.equal(100, result.done)
    end)

    it("treats a single yes/no criterion as 0 or 1", function()
      assert.same({ done = 0, total = 1, fraction = 0 }, Achievements.progress({ { completed = false, required = 1 } }))
    end)
  end)

  describe("isSoloCategory", function()
    it("excludes PvP, Feats of Strength and Legacy", function()
      assert.is_false(Achievements.isSoloCategory(95))
      assert.is_false(Achievements.isSoloCategory(81))
      assert.is_false(Achievements.isSoloCategory(15234))
    end)

    it("includes everything else", function()
      assert.is_true(Achievements.isSoloCategory(96))
      assert.is_true(Achievements.isSoloCategory(168))
    end)
  end)

  describe("lines", function()
    it("lists almost-done achievements by progress, with reward and group tag", function()
      local lines = Achievements.lines({
        entry("Low", 0.8, { done = 8 }),
        entry("High", 0.9, { done = 9, reward = "Reward: Title", group = true }),
        entry("Far", 0.1, { done = 1 }),
      })

      assert.same({
        "Almost done (75%+)",
        "  90% High (9/10) - Reward: Title [group]",
        "  80% Low (8/10)",
        "With rewards",
        "  None right now.",
      }, lines)
    end)

    it("lists rewarding achievements below the almost-done threshold", function()
      local lines = Achievements.lines({
        entry("Mount run", 0.4, { done = 4, reward = "Reward: Mount" }),
        entry("Plain", 0.5, { done = 5 }),
      })

      assert.same({
        "Almost done (75%+)",
        "  None right now.",
        "With rewards",
        "  40% Mount run (4/10) - Reward: Mount",
      }, lines)
    end)

    it("caps each list", function()
      local many = {}
      for index = 1, Achievements.LIST_LIMIT + 5 do
        many[index] = entry("A" .. index, 0.8)
      end

      local lines = Achievements.lines(many)

      assert.equal(1 + Achievements.LIST_LIMIT + 2, #lines)
    end)

    it("rounds percentages down", function()
      local lines = Achievements.lines({ entry("Nearly", 0.999, { done = 999, total = 1000 }) })

      assert.equal("  99% Nearly (999/1000)", lines[2])
    end)
  end)
end)
