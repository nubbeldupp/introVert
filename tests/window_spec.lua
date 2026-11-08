local helper = require("tests.helper")
local Wow = require("tests.support.wow")

describe("Window", function()
  local env, ns

  local function windowHas(text)
    return (ns.Window.GetText() or ""):find(text, 1, true) ~= nil
  end

  local function tab(title)
    for _, button in ipairs(env.buttons) do
      if button.text == title then
        return button
      end
    end
    error("no tab " .. title)
  end

  before_each(function()
    env = Wow.install()
    env.mounts = { [50818] = { mountID = 363, name = "Invincible", collected = false } }
    ns = Wow.loadAddon(helper)
    ns.RaidMountData = {
      raids = { { instanceID = 631, name = "Icecrown Citadel", mounts = { { itemID = 50818, boss = "The Lich King" } } } },
    }
    env.fire("ADDON_LOADED", "IntroVert")
    env.fire("UPDATE_INSTANCE_INFO")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  describe("Format", function()
    it("colours header lines and keeps indented detail lines plain", function()
      local text = ns.Window.Format({ "Icecrown Citadel - free: Abe", "  Invincible - The Lich King" })

      assert.equal("|cffffd100Icecrown Citadel - free: Abe|r\n  Invincible - The Lich King", text)
    end)

    it("returns an empty string for no lines", function()
      assert.equal("", ns.Window.Format({}))
    end)
  end)

  describe("opening", function()
    it("is not created until first opened", function()
      assert.is_false(ns.Window.IsShown())
      for _, button in ipairs(env.buttons) do
        assert.is_nil(rawget(button, "text"), "no tab buttons before first open")
      end
    end)

    it("/iv mounts opens the Mounts tab", function()
      env.slash("mounts")

      assert.is_true(ns.Window.IsShown())
      assert.equal("mounts", ns.Window.CurrentView())
      assert.is_true(windowHas("Invincible - The Lich King, 0 attempts"))
    end)

    it("/iv raids opens the Raids tab", function()
      env.slash("raids")

      assert.equal("raids", ns.Window.CurrentView())
      assert.is_true(windowHas("Nubbel-Silvermoon|r\n  no active raid lockouts"))
    end)

    it("names the open view in the title", function()
      env.slash("mounts")

      assert.equal("introVert - Mounts", ns.Window.GetTitle())
    end)

    it("/iv window toggles and starts on the first tab", function()
      env.slash("window")
      assert.is_true(ns.Window.IsShown())
      assert.equal("raids", ns.Window.CurrentView())

      env.slash("window")
      assert.is_false(ns.Window.IsShown())
    end)

    it("reopens on the last tab used", function()
      env.slash("mounts")
      env.slash("window")

      env.slash("window")

      assert.equal("mounts", ns.Window.CurrentView())
    end)

    it("closes with Escape", function()
      env.slash("window")

      assert.same({ "IntroVertWindow" }, UISpecialFrames)
    end)

    it("is listed in /iv help", function()
      env.slash("help")

      assert.is_true(env.printed("/iv window"))
    end)
  end)

  describe("tabs", function()
    it("switches view when a tab is clicked", function()
      env.slash("raids")

      tab("Mounts"):Click()

      assert.equal("mounts", ns.Window.CurrentView())
      assert.is_true(windowHas("Invincible"))
    end)

    it("highlights the open tab and keeps every tab clickable", function()
      env.slash("mounts")

      assert.is_true(tab("Mounts").highlightLocked)
      assert.is_false(tab("Raids").highlightLocked)
      assert.is_true(tab("Mounts").enabled)
      assert.is_true(tab("Raids").enabled)
    end)

    it("moves the highlight when switching tabs", function()
      env.slash("mounts")

      tab("Raids"):Click()

      assert.is_true(tab("Raids").highlightLocked)
      assert.is_false(tab("Mounts").highlightLocked)
    end)
  end)

  describe("live updates", function()
    it("redraws when a mount attempt is counted while open", function()
      env.slash("mounts")
      env.instance = { inInstance = true, instanceType = "raid", difficultyID = 6, instanceID = 631 }

      env.fire("ENCOUNTER_END", 1, "The Lich King", 6, 25, 1)

      assert.is_true(windowHas("Invincible - The Lich King, 1 attempt"))
    end)

    it("redraws when mount items finish loading", function()
      env.uncachedItems = { [50818] = true }
      env.slash("mounts")
      assert.is_true(windowHas("Still loading 1 mounts"))
      env.uncachedItems = {}

      env.fire("ITEM_DATA_LOAD_RESULT", 50818, true)

      assert.is_true(windowHas("Invincible"))
    end)

    it("does nothing while hidden", function()
      env.slash("mounts")
      env.slash("window")
      local before = ns.Window.GetText()
      env.uncachedItems = { [50818] = true }

      ns.Window.Refresh()

      assert.equal(before, ns.Window.GetText())
    end)
  end)
end)
