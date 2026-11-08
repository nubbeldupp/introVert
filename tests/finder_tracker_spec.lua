local helper = require("tests.helper")
local Wow = require("tests.support.wow")

local DAY = 24 * 3600

describe("Solo Content Finder", function()
  local env, ns

  local function windowHas(text)
    return (ns.Window.GetText() or ""):find(text, 1, true) ~= nil
  end

  before_each(function()
    env = Wow.install()
    env.mounts = {
      [50818] = { mountID = 363, name = "Invincible", collected = false },
      [30480] = { mountID = 168, name = "Fiery Warhorse", collected = false },
    }
    env.vault = { { index = 1, threshold = 2, progress = 1, level = 0 } }
    env.zones = { { mapID = 1, name = "Eversong Woods" } }
    env.delvePois = { [1] = { { poiID = 9, name = "Collegiate Calamity", atlasName = "delves-bountiful" } } }
    env.achievementCategories = {
      { id = 96, title = "Quests", parent = -1, achievements = {
        { id = 1, name = "Anvil Mastery II", points = 10, completed = false, reward = "", isGuild = false,
          criteria = { { completed = false, quantity = 491, required = 500 } } },
      } },
    }
    env.savedInstances = {
      { name = "Karazhan", reset = 2 * DAY, difficultyID = 3, difficultyName = "10 Player", locked = true,
        extended = false, isRaid = true, numEncounters = 11, encounterProgress = 1, instanceID = 532 },
    }
    ns = Wow.loadAddon(helper)
    ns.RaidMountData = { raids = {
      { instanceID = 631, name = "Icecrown Citadel", minutes = 20, mounts = { { itemID = 50818, boss = "The Lich King" } } },
      { instanceID = 532, name = "Karazhan", minutes = 15, mounts = { { itemID = 30480, boss = "Attumen the Huntsman" } } },
    } }
    env.fire("ADDON_LOADED", "IntroVert")
    env.fire("UPDATE_INSTANCE_INFO")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  it("/iv finder opens a plan built from raids, delves and achievements", function()
    env.slash("finder")

    assert.equal("finder", ns.Window.CurrentView())
    assert.is_true(windowHas("Plan for 60 min (about 35 min planned)"))
    assert.is_true(windowHas("  15 min  Bountiful delve: Collegiate Calamity (Eversong Woods) (vault)"))
    assert.is_true(windowHas("  20 min  Icecrown Citadel: Invincible"))
    assert.is_true(windowHas("  98% Anvil Mastery II (491/500)"))
  end)

  it("leaves out raids this character is already locked to", function()
    env.slash("finder")

    assert.is_false(windowHas("Karazhan"))
  end)

  it("/iv finder <minutes> sets and saves the budget", function()
    env.slash("finder 15")

    assert.equal(15, IntroVertDB.finder.minutes)
    assert.is_true(windowHas("Plan for 15 min (about 15 min planned)"))
    assert.is_true(windowHas("Also worth doing|r\n  20 min  Icecrown Citadel: Invincible"))
  end)

  it("/iv solo is a shortcut", function()
    env.slash("solo")

    assert.equal("finder", ns.Window.CurrentView())
  end)

  it("rejects a budget outside 5 to 600 minutes", function()
    env.slash("finder 2")

    assert.equal(60, IntroVertDB.finder.minutes)
    assert.is_true(env.printed("Give a session length between 5 and 600 minutes"))
  end)

  it("keeps working when one source fails", function()
    _G.C_WeeklyRewards.GetActivities = function() error("api changed") end
    _G.GetCategoryList = function() error("api changed") end

    env.slash("finder")

    assert.is_true(windowHas("Bountiful delve: Collegiate Calamity (Eversong Woods)"))
    assert.is_false(windowHas("(vault)"))
    assert.is_true(windowHas("Icecrown Citadel: Invincible"))
  end)

  it("adds a session length slider to the options page", function()
    local setting = env.settings.byVariable["IntroVert_finder_minutes"]

    assert.equal(60, setting.default)
    setting:SetValue(90)
    assert.equal(90, IntroVertDB.finder.minutes)
  end)

  it("is listed in /iv help", function()
    env.slash("help")

    assert.is_true(env.printed("/iv finder [minutes]"))
  end)
end)
