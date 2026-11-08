local helper = require("tests.helper")

describe("Defaults", function()
  local Defaults

  before_each(function()
    Defaults = helper.loadPure({ "Core/Defaults.lua" }).Defaults
  end)

  describe("merge", function()
    it("returns a copy of defaults when nothing is saved", function()
      local merged = Defaults.merge(Defaults.values, nil)

      assert.same(Defaults.values, merged)
      assert.are_not.equal(Defaults.values, merged)
      assert.are_not.equal(Defaults.values.quiet, merged.quiet)
    end)

    it("keeps saved values whose type matches the default", function()
      local saved = { quiet = { greet = false, chatLevel = { lfr = "all" } } }

      local merged = Defaults.merge(Defaults.values, saved)

      assert.is_false(merged.quiet.greet)
      assert.equal("all", merged.quiet.chatLevel.lfr)
      assert.equal("keywords", merged.quiet.chatLevel.dungeon)
    end)

    it("falls back to defaults when the saved type is wrong", function()
      local saved = { quiet = { wipeMuteSeconds = "lots", greet = "yes" } }

      local merged = Defaults.merge(Defaults.values, saved)

      assert.equal(30, merged.quiet.wipeMuteSeconds)
      assert.is_true(merged.quiet.greet)
    end)

    it("replaces lists wholesale instead of merging by index", function()
      local saved = { quiet = { greetings = { "yo" } } }

      local merged = Defaults.merge(Defaults.values, saved)

      assert.same({ "yo" }, merged.quiet.greetings)
    end)

    it("drops keys that no longer exist in defaults", function()
      local merged = Defaults.merge(Defaults.values, { legacyThing = 1 })

      assert.is_nil(merged.legacyThing)
    end)

    it("does not mutate the saved table", function()
      local saved = { quiet = { greet = false } }

      Defaults.merge(Defaults.values, saved)

      assert.same({ quiet = { greet = false } }, saved)
    end)
  end)

  describe("with", function()
    it("returns a new table with the path replaced", function()
      local original = { quiet = { chatLevel = { lfr = "keywords" } } }

      local updated = Defaults.with(original, { "quiet", "chatLevel", "lfr" }, "all")

      assert.equal("all", updated.quiet.chatLevel.lfr)
      assert.equal("keywords", original.quiet.chatLevel.lfr)
    end)

    it("creates missing intermediate tables", function()
      local updated = Defaults.with({}, { "a", "b" }, 1)

      assert.same({ a = { b = 1 } }, updated)
    end)
  end)

  describe("get", function()
    it("reads a nested value", function()
      assert.equal("keywords", Defaults.get(Defaults.values, { "quiet", "chatLevel", "lfr" }))
    end)

    it("returns nil for a missing path", function()
      assert.is_nil(Defaults.get({ a = 1 }, { "a", "b", "c" }))
      assert.is_nil(Defaults.get(nil, { "a" }))
    end)
  end)
end)
