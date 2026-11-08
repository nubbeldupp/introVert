local helper = require("tests.helper")

describe("Quiet Filter", function()
  local Filter

  before_each(function()
    Filter = helper.loadPure({ "Modules/Quiet/Filter.lua" }).QuietFilter
  end)

  local needles = { "wait", "afk", "nubbel", "tank" }

  local function opts(level, strict)
    return { level = level, needles = needles, strict = strict or false }
  end

  describe("buildNeedles", function()
    it("combines keywords, player name and role word", function()
      local result = Filter.buildNeedles({ "wait" }, "Nubbel", "TANK")

      assert.same({ "wait", "nubbel", "tank" }, result)
    end)

    it("adds no role word for damage dealers", function()
      local result = Filter.buildNeedles({}, "Nubbel", "DAMAGER")

      assert.same({ "nubbel" }, result)
    end)

    it("skips a missing player name", function()
      assert.same({ "heal" }, Filter.buildNeedles({}, nil, "HEALER"))
    end)
  end)

  describe("shouldHide", function()
    it("never hides when level is off", function()
      assert.is_false(Filter.shouldHide({ text = "spam" }, opts("off")))
    end)

    it("never hides your own messages", function()
      assert.is_false(Filter.shouldHide({ text = "hi", isSelf = true }, opts("all")))
    end)

    it("hides everything at level all", function()
      assert.is_true(Filter.shouldHide({ text = "wait for me" }, opts("all")))
    end)

    it("shows keyword matches at level keywords, case-insensitive", function()
      assert.is_false(Filter.shouldHide({ text = "WAIT pls" }, opts("keywords")))
      assert.is_false(Filter.shouldHide({ text = "nice pull Nubbel" }, opts("keywords")))
    end)

    it("hides non-matching chatter at level keywords", function()
      assert.is_true(Filter.shouldHide({ text = "go go go" }, opts("keywords")))
    end)

    it("treats keywords as plain text, not patterns", function()
      local patternOpts = { level = "keywords", needles = { "a.c" } }

      assert.is_true(Filter.shouldHide({ text = "abc" }, patternOpts))
      assert.is_false(Filter.shouldHide({ text = "a.c" }, patternOpts))
    end)

    it("shows only the leader at level leader", function()
      assert.is_false(Filter.shouldHide({ text = "pull", isLeader = true }, opts("leader")))
      assert.is_true(Filter.shouldHide({ text = "pull", isLeader = false }, opts("leader")))
    end)

    it("hides everything while strict mode is on", function()
      assert.is_true(Filter.shouldHide({ text = "wait" }, opts("keywords", true)))
    end)

    it("does not let strict mode override a level of off", function()
      assert.is_false(Filter.shouldHide({ text = "go" }, opts("off", true)))
    end)

    it("still shows own messages in strict mode", function()
      assert.is_false(Filter.shouldHide({ text = "x", isSelf = true }, opts("off", true)))
    end)

    it("shows secret (unreadable) messages unless muting everything", function()
      local secret = { isSecret = true }

      assert.is_false(Filter.shouldHide(secret, opts("keywords")))
      assert.is_false(Filter.shouldHide(secret, opts("leader")))
      assert.is_true(Filter.shouldHide(secret, opts("all")))
    end)

    it("treats an unknown level as off", function()
      assert.is_false(Filter.shouldHide({ text = "x" }, opts("bogus")))
    end)
  end)

  describe("isValidLevel", function()
    it("accepts known levels only", function()
      assert.is_true(Filter.isValidLevel("keywords"))
      assert.is_false(Filter.isValidLevel("loud"))
    end)
  end)
end)
