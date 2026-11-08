local helper = require("tests.helper")
local Wow = require("tests.support.wow")

describe("Minimap button (addon compartment)", function()
  local env, ns

  before_each(function()
    env = Wow.install()
    ns = Wow.loadAddon(helper)
    env.fire("ADDON_LOADED", "IntroVert")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  it("is declared in the TOC with functions that exist", function()
    local toc = io.open("IntroVert.toc"):read("*a")

    for field, fn in toc:gmatch("## (AddonCompartmentFunc%a*): (%S+)") do
      assert.equal("function", type(_G[fn]), field)
    end
    assert.is_truthy(toc:find("## AddonCompartmentFunc: ", 1, true))
    assert.is_truthy(toc:find("## IconTexture: ", 1, true))
  end)

  it("left-click toggles the window", function()
    IntroVert_OnAddonCompartmentClick("IntroVert", "LeftButton")
    assert.is_true(ns.Window.IsShown())

    IntroVert_OnAddonCompartmentClick("IntroVert", "LeftButton")
    assert.is_false(ns.Window.IsShown())
  end)

  it("right-click opens the options", function()
    IntroVert_OnAddonCompartmentClick("IntroVert", "RightButton")

    assert.is_not_nil(env.settings.opened)
  end)

  it("shows and hides a tooltip", function()
    IntroVert_OnAddonCompartmentEnter("IntroVert", {})

    assert.is_true(env.tooltip.shown)
    assert.same({ "introVert", "Left-click: open the window", "Right-click: options" }, env.tooltip.lines)

    IntroVert_OnAddonCompartmentLeave("IntroVert", {})

    assert.is_false(env.tooltip.shown)
  end)
end)
