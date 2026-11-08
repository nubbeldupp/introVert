local helper = require("tests.helper")
local Wow = require("tests.support.wow")

describe("Achievement tracker", function()
  local env, ns

  local function windowHas(text)
    return (ns.Window.GetText() or ""):find(text, 1, true) ~= nil
  end

  local function achievement(id, name, criteria, overrides)
    local base = { id = id, name = name, points = 10, completed = false, reward = "", isGuild = false, criteria = criteria }
    for key, value in pairs(overrides or {}) do
      base[key] = value
    end
    return base
  end

  local function done(count, total)
    local criteria = {}
    for index = 1, total do
      criteria[index] = { completed = index <= count, quantity = 0, required = 1 }
    end
    return criteria
  end

  before_each(function()
    env = Wow.install()
    env.achievementCategories = {
      { id = 96, title = "Quests", parent = -1, achievements = {
        achievement(1, "Loremaster", done(9, 10), { reward = "Reward: Title" }),
        achievement(2, "Finished", done(10, 10), { completed = true }),
        achievement(3, "Guild Quests", done(9, 10), { isGuild = true }),
        achievement(4, "No Criteria", {}),
      } },
      { id = 9601, title = "Quests: Khaz Algar", parent = 96, achievements = {
        achievement(5, "Counter", { { completed = false, quantity = 80, required = 100 } }),
      } },
      { id = 95, title = "Player vs. Player", parent = -1, achievements = {
        achievement(6, "Arena", done(9, 10)),
      } },
      { id = 9501, title = "Arena", parent = 95, achievements = {
        achievement(7, "Rated", done(9, 10)),
      } },
      { id = 168, title = "Dungeons & Raids", parent = -1, achievements = {
        achievement(8, "Glory", done(4, 10), { reward = "Reward: Mount" }),
      } },
    }
    ns = Wow.loadAddon(helper)
    env.fire("ADDON_LOADED", "IntroVert")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  it("/iv achievements opens the tab with almost-done and rewarding achievements", function()
    env.slash("achievements")

    assert.equal("achievements", ns.Window.CurrentView())
    assert.is_true(windowHas("  90% Loremaster (9/10) - Reward: Title"))
    assert.is_true(windowHas("  80% Counter (80/100)"))
    assert.is_true(windowHas("  40% Glory (4/10) - Reward: Mount [group]"))
  end)

  it("/iv ach is a shortcut", function()
    env.slash("ach")

    assert.equal("achievements", ns.Window.CurrentView())
  end)

  it("leaves out completed, guild, criteria-less and PvP achievements", function()
    env.slash("achievements")

    assert.is_false(windowHas("Finished"))
    assert.is_false(windowHas("Guild Quests"))
    assert.is_false(windowHas("No Criteria"))
    assert.is_false(windowHas("Arena"))
    assert.is_false(windowHas("Rated"))
  end)

  it("scans once and reuses the result until progress changes", function()
    env.slash("achievements")
    env.slash("window")
    env.slash("achievements")
    assert.equal(1, env.achievementScans)

    env.fire("CRITERIA_UPDATE")
    env.slash("window")
    env.slash("achievements")

    assert.equal(2, env.achievementScans)
  end)

  it("does not rescan immediately on progress changes", function()
    env.slash("achievements")

    env.fire("CRITERIA_UPDATE")

    assert.equal(1, env.achievementScans)
  end)

  it("rescans and redraws when an achievement is earned", function()
    env.slash("achievements")
    env.achievementCategories[1].achievements[1].completed = true

    env.fire("ACHIEVEMENT_EARNED", 1)

    assert.is_false(windowHas("Loremaster"))
  end)

  it("shows the tab as unavailable when the achievement API fails", function()
    _G.GetCategoryList = function() error("api changed") end

    env.slash("achievements")

    assert.is_true(windowHas("Not available on this client."))
  end)

  it("is listed in /iv help", function()
    env.slash("help")

    assert.is_true(env.printed("/iv achievements"))
  end)
end)
