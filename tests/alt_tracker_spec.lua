local helper = require("tests.helper")
local Wow = require("tests.support.wow")

local DAY = 24 * 3600

describe("Alts tab", function()
  local env, ns

  local function windowHas(text)
    return (ns.Window.GetText() or ""):find(text, 1, true) ~= nil
  end

  before_each(function()
    env = Wow.install()
    env.itemLevel = 712.6
    env.money = 123456789
    env.level = 90
    env.vault = {
      { type = 3, index = 1, progress = 2, threshold = 2, level = 0 },
      { type = 6, index = 1, progress = 2, threshold = 2, level = 11 },
    }
    env.secondsUntilReset = 3 * DAY
    ns = Wow.loadAddon(helper)
    env.fire("ADDON_LOADED", "IntroVert")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  it("records the character on login", function()
    env.fire("PLAYER_ENTERING_WORLD")

    assert.same({
      level = 90, race = "Dwarf", class = "Rogue", itemLevel = 712, gold = 123456789, hasRewards = false,
      vault = { raid = 1, dungeon = 0, world = 1 }, updatedAt = env.time,
    }, IntroVertDB.alts["Nubbel-Silvermoon"])
  end)

  it("updates when gold changes", function()
    env.fire("PLAYER_ENTERING_WORLD")
    env.money = 5

    env.fire("PLAYER_MONEY")

    assert.equal(5, IntroVertDB.alts["Nubbel-Silvermoon"].gold)
  end)

  it("/iv alts opens the Alts tab", function()
    env.fire("PLAYER_ENTERING_WORLD")

    env.slash("alts")

    assert.equal("alts", ns.Window.CurrentView())
    assert.is_true(windowHas("Nubbel-Silvermoon (90 Dwarf Rogue, ilvl 712) - online"))
    assert.is_true(windowHas("  Vault: raid 1/3, dungeons 0/3, world 1/3"))
  end)

  it("marks a vault from before the weekly reset as stale", function()
    _G.IntroVertDB.alts["Old-Silvermoon"] = {
      level = 80, itemLevel = 600, gold = 0, hasRewards = true,
      vault = { raid = 3, dungeon = 3, world = 3 }, updatedAt = env.time - 6 * DAY,
    }

    env.slash("alts")

    assert.is_true(windowHas("Old-Silvermoon (80, ilvl 600) - seen 6d 0h ago|r\n  Vault: reset since last seen"))
    assert.is_true(windowHas("  Rewards waiting in the Great Vault"))
  end)

  it("records without vault data when the vault API fails", function()
    _G.C_WeeklyRewards.GetActivities = function() error("api changed") end

    env.fire("PLAYER_ENTERING_WORLD")

    assert.is_nil(IntroVertDB.alts["Nubbel-Silvermoon"].vault)
    assert.equal(90, IntroVertDB.alts["Nubbel-Silvermoon"].level)
  end)

  it("/iv raids forget also removes the character from the Alts tab", function()
    _G.IntroVertDB.characters["Alt-Silvermoon"] = { lockouts = {}, updatedAt = env.time }
    _G.IntroVertDB.alts["Alt-Silvermoon"] = { level = 1, itemLevel = 1, gold = 0, updatedAt = env.time }

    env.slash("raids forget Alt-Silvermoon")

    assert.is_nil(IntroVertDB.alts["Alt-Silvermoon"])
  end)

  it("is listed in /iv help", function()
    env.slash("help")

    assert.is_true(env.printed("/iv alts"))
  end)
end)
