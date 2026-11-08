local helper = require("tests.helper")

describe("Lists", function()
  local Lists

  before_each(function()
    Lists = helper.loadPure({ "Core/Lists.lua" }).Lists
  end)

  describe("parse", function()
    it("splits on commas and trims whitespace", function()
      assert.same({ "wait", "afk", "brb" }, Lists.parse(" wait,afk ,  brb "))
    end)

    it("drops empty entries", function()
      assert.same({ "hi o/" }, Lists.parse(",, hi o/ ,"))
    end)

    it("drops case-insensitive duplicates, keeping the first spelling", function()
      assert.same({ "Wait", "afk" }, Lists.parse("Wait, afk, wait, AFK"))
    end)

    it("cuts entries to the chat message length limit", function()
      local result = Lists.parse(string.rep("a", 300))

      assert.equal(Lists.MAX_ENTRY_LENGTH, #result[1])
    end)

    it("keeps at most MAX_ENTRIES entries", function()
      local parts = {}
      for index = 1, Lists.MAX_ENTRIES + 5 do
        parts[index] = "w" .. index
      end

      local result = Lists.parse(table.concat(parts, ","))

      assert.equal(Lists.MAX_ENTRIES, #result)
      assert.equal("w1", result[1])
    end)

    it("returns an empty list for blank or missing input", function()
      assert.same({}, Lists.parse("   "))
      assert.same({}, Lists.parse(nil))
    end)
  end)

  describe("format", function()
    it("joins entries with comma and space", function()
      assert.equal("wait, afk", Lists.format({ "wait", "afk" }))
    end)

    it("formats an empty or missing list as an empty string", function()
      assert.equal("", Lists.format({}))
      assert.equal("", Lists.format(nil))
    end)

    it("round-trips through parse", function()
      local list = { "hi o/", "hey" }

      assert.same(list, Lists.parse(Lists.format(list)))
    end)
  end)
end)
