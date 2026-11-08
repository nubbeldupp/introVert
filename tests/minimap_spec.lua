local helper = require("tests.helper")
local Wow = require("tests.support.wow")

describe("Minimap button", function()
  local env, ns

  local function button()
    for _, candidate in ipairs(env.buttons) do
      if candidate.name == "IntroVertMinimapButton" then
        return candidate
      end
    end
    error("no minimap button")
  end

  before_each(function()
    env = Wow.install()
    ns = Wow.loadAddon(helper)
    env.fire("ADDON_LOADED", "IntroVert")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  it("is shown on the minimap by default", function()
    assert.is_true(button():IsShown())
    assert.equal(Minimap, button().parent)
  end)

  it("sits on the minimap edge at the saved angle", function()
    ns.UpdateSetting({ "minimap", "angle" }, 0)

    local point = button().point
    assert.equal("CENTER", point[1])
    assert.equal(Minimap, point[2])
    assert.near(80, point[4], 0.001)
    assert.near(0, point[5], 0.001)
  end)

  it("left-click toggles the window, right-click opens options", function()
    button().scripts.OnClick(button(), "LeftButton")
    assert.is_true(ns.Window.IsShown())

    button().scripts.OnClick(button(), "RightButton")
    assert.is_not_nil(env.settings.opened)
  end)

  it("shows a tooltip on hover", function()
    button().scripts.OnEnter(button())
    assert.is_true(env.tooltip.shown)

    button().scripts.OnLeave(button())
    assert.is_false(env.tooltip.shown)
  end)

  it("follows the cursor while dragged and saves the new angle", function()
    button().scripts.OnDragStart(button())
    env.cursorX, env.cursorY = 100, 180

    button().scripts.OnUpdate(button())
    button().scripts.OnDragStop(button())

    assert.near(90, IntroVertDB.minimap.angle, 0.001)
    assert.is_nil(button().scripts.OnUpdate)
  end)

  it("hides when switched off and comes back when switched on", function()
    ns.UpdateSetting({ "minimap", "show" }, false)
    assert.is_false(button():IsShown())

    env.slash("minimap")
    assert.is_true(button():IsShown())
    assert.is_true(env.printed("Minimap button shown."))
  end)

  it("adds a switch to the options page", function()
    assert.is_not_nil(env.settings.byVariable["IntroVert_minimap_show"])
  end)

  it("is listed in /iv help", function()
    env.slash("help")

    assert.is_true(env.printed("/iv minimap"))
  end)
end)
