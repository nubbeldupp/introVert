local helper = require("tests.helper")

describe("Quiet Profile.resolve", function()
  local Profile

  before_each(function()
    Profile = helper.loadPure({ "Modules/Quiet/Profile.lua" }).QuietProfile
  end)

  local function ctx(overrides)
    local base = { inInstance = true, isLFG = true, instanceType = "party", difficultyID = 1 }
    for key, value in pairs(overrides or {}) do
      base[key] = value
    end
    return base
  end

  it("returns dungeon for a matchmade 5-man", function()
    assert.equal(Profile.DUNGEON, Profile.resolve(ctx()))
  end)

  it("returns lfr for a Raid Finder raid", function()
    assert.equal(Profile.LFR, Profile.resolve(ctx({ instanceType = "raid", difficultyID = 17 })))
  end)

  it("treats legacy LFR and timewalking raids as lfr", function()
    assert.equal(Profile.LFR, Profile.resolve(ctx({ instanceType = "raid", difficultyID = 7 })))
    assert.equal(Profile.LFR, Profile.resolve(ctx({ instanceType = "raid", difficultyID = 33 })))
    assert.equal(Profile.LFR, Profile.resolve(ctx({ instanceType = "raid", difficultyID = 151 })))
  end)

  it("ignores normal/heroic raids even when queued", function()
    assert.is_nil(Profile.resolve(ctx({ instanceType = "raid", difficultyID = 14 })))
  end)

  it("ignores follower dungeons", function()
    assert.is_nil(Profile.resolve(ctx({ difficultyID = 205 })))
  end)

  it("ignores premade groups", function()
    assert.is_nil(Profile.resolve(ctx({ isLFG = false })))
  end)

  it("ignores the open world", function()
    assert.is_nil(Profile.resolve(ctx({ inInstance = false, instanceType = "none" })))
  end)

  it("handles a missing context", function()
    assert.is_nil(Profile.resolve(nil))
  end)

  describe("isEnabled", function()
    it("checks the per-profile toggle", function()
      local settings = { enabled = { dungeon = true, lfr = false } }

      assert.is_true(Profile.isEnabled(Profile.DUNGEON, settings))
      assert.is_false(Profile.isEnabled(Profile.LFR, settings))
      assert.is_false(Profile.isEnabled(nil, settings))
    end)
  end)
end)
