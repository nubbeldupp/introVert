local helper = require("tests.helper")

describe("Quiet Phrases.pick", function()
  local Phrases

  before_each(function()
    Phrases = helper.loadPure({ "Modules/Quiet/Phrases.lua" }).QuietPhrases
  end)

  it("picks the entry chosen by the random function", function()
    local alwaysSecond = function(max)
      assert.equal(3, max)
      return 2
    end

    assert.equal("b", Phrases.pick({ "a", "b", "c" }, alwaysSecond))
  end)

  it("returns nil for an empty or missing list", function()
    assert.is_nil(Phrases.pick({}, math.random))
    assert.is_nil(Phrases.pick(nil, math.random))
  end)

  it("skips blank entries", function()
    assert.equal("hi", Phrases.pick({ "  ", "hi" }, function() return 1 end))
  end)
end)
