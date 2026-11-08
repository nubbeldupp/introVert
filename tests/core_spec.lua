local helper = require("tests.helper")
local Wow = require("tests.support.wow")

describe("Core", function()
  local env, ns

  before_each(function()
    env = Wow.install()
    ns = Wow.loadAddon(helper)
  end)

  after_each(function()
    Wow.uninstall()
  end)

  it("builds settings from defaults on ADDON_LOADED", function()
    env.fire("ADDON_LOADED", "IntroVert")

    assert.same(ns.Defaults.values, IntroVertDB)
    assert.equal(IntroVertDB, ns.db)
  end)

  it("keeps previously saved settings", function()
    -- busted sandboxes spec globals; the addon reads the real _G.
    _G.IntroVertDB = { quiet = { greet = false } }

    env.fire("ADDON_LOADED", "IntroVert")

    assert.is_false(ns.db.quiet.greet)
  end)

  it("ignores ADDON_LOADED for other addons", function()
    env.fire("ADDON_LOADED", "SomethingElse")

    assert.is_nil(ns.db)
  end)

  it("reports a failing handler and still runs the others", function()
    local ran = false
    ns.On("TEST_EVENT", function() error("boom") end)
    ns.On("TEST_EVENT", function() ran = true end)

    env.fire("TEST_EVENT")

    assert.is_true(ran)
    assert.equal(1, #env.errors)
    assert.matches("boom", env.errors[1])
  end)

  it("UpdateSetting swaps in a new settings table", function()
    env.fire("ADDON_LOADED", "IntroVert")
    local before = ns.db

    ns.UpdateSetting({ "quiet", "greet" }, false)

    assert.are_not.equal(before, ns.db)
    assert.is_true(before.quiet.greet)
    assert.is_false(IntroVertDB.quiet.greet)
  end)

  it("notifies settings listeners after an update", function()
    env.fire("ADDON_LOADED", "IntroVert")
    local seen
    ns.OnSettingsChanged(function(path) seen = path end)

    ns.UpdateSetting({ "quiet", "greet" }, false)

    assert.same({ "quiet", "greet" }, seen)
  end)

  it("keeps notifying listeners when one fails", function()
    env.fire("ADDON_LOADED", "IntroVert")
    local ran = false
    ns.OnSettingsChanged(function() error("listener boom") end)
    ns.OnSettingsChanged(function() ran = true end)

    ns.UpdateSetting({ "quiet", "greet" }, false)

    assert.is_true(ran)
    assert.matches("listener boom", env.errors[1])
  end)

  it("points to /iv help for an unknown slash command", function()
    env.slash("nope")

    assert.matches("Unknown command 'nope'", env.lastPrint())
    assert.matches("/iv help", env.lastPrint())
  end)

  it("/iv help lists every registered command", function()
    env.slash("help")

    assert.is_true(env.printed("/iv help"))
    assert.is_true(env.printed("/iv quiet on | off"))
    assert.is_true(env.printed("/iv quiet log"))
    assert.is_true(env.printed("levels: off, all, keywords, leader"))
  end)

  it("/iv with no arguments shows help", function()
    env.slash("")

    assert.is_true(env.printed("/iv quiet dungeon <level>"))
  end)

  it("lists modules in alphabetical order", function()
    ns.RegisterCommand("aaa", function() end, { "/iv aaa - first" })

    env.slash("help")

    local aaa, quiet
    for index, line in ipairs(env.prints) do
      aaa = aaa or (line:find("/iv aaa", 1, true) and index)
      quiet = quiet or (line:find("/iv quiet", 1, true) and index)
    end
    assert.is_true(aaa < quiet)
  end)

  it("accepts commands registered without help lines", function()
    ns.RegisterCommand("bare", function() end)

    env.slash("help")

    assert.is_true(env.printed("/iv quiet"))
  end)
end)
