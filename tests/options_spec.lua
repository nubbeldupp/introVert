local helper = require("tests.helper")
local Wow = require("tests.support.wow")

describe("Options panel", function()
  local env, ns

  local function setting(name)
    return assert(env.settings.byVariable["IntroVert_" .. name], "no setting " .. name)
  end

  local function control(name)
    for _, entry in ipairs(env.settings.controls) do
      if entry.setting.variable == "IntroVert_" .. name then
        return entry
      end
    end
    error("no control for " .. name)
  end

  local function button(label)
    for _, init in ipairs(env.settings.initializers) do
      if init.kind == "button" and init.name == label then
        return init
      end
    end
    error("no button " .. label)
  end

  local function enterDungeon()
    env.isLFG = true
    env.instance = { inInstance = true, instanceType = "party", difficultyID = 2 }
    env.fire("PLAYER_ENTERING_WORLD")
  end

  before_each(function()
    env = Wow.install()
    ns = Wow.loadAddon(helper)
    env.fire("ADDON_LOADED", "IntroVert")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  describe("registration", function()
    it("registers one introVert category under AddOns", function()
      assert.equal(1, #env.settings.categories)
      assert.equal("introVert", env.settings.categories[1].name)
    end)

    it("adds General and Quiet Groups section headers, General first", function()
      local headers = {}
      for _, init in ipairs(env.settings.initializers) do
        if init.kind == "header" then
          headers[#headers + 1] = init.text
        end
      end

      assert.equal("General", headers[1])
      assert.equal("Quiet Groups", headers[2])
    end)

    it("creates a control for every Quiet setting", function()
      local expected = {
        quiet_enabled_dungeon = "checkbox",
        quiet_enabled_lfr = "checkbox",
        quiet_chatLevel_dungeon = "dropdown",
        quiet_chatLevel_lfr = "dropdown",
        quiet_encounterFocus = "checkbox",
        quiet_wipeMuteSeconds = "slider",
        quiet_greet = "checkbox",
        quiet_farewell = "checkbox",
        quiet_readyAlarm = "checkbox",
      }
      for name, kind in pairs(expected) do
        assert.equal(kind, control(name).kind, name)
      end
    end)

    it("uses the default value for each setting", function()
      assert.is_true(setting("quiet_greet").default)
      assert.equal("keywords", setting("quiet_chatLevel_lfr").default)
      assert.equal(30, setting("quiet_wipeMuteSeconds").default)
    end)

    it("offers every chat level in the dropdowns", function()
      local choices = control("quiet_chatLevel_dungeon").options()

      local values = {}
      for _, choice in ipairs(choices) do
        values[#values + 1] = choice.value
      end
      assert.same({ "off", "keywords", "leader", "all" }, values)
    end)

    it("configures the wipe slider range", function()
      local options = control("quiet_wipeMuteSeconds").options

      assert.same({ 0, 120, 5 }, { options.min, options.max, options.step })
    end)

    it("reports a failed build without breaking the addon", function()
      Wow.uninstall()
      env = Wow.install()
      _G.Settings.RegisterVerticalLayoutCategory = function() error("api changed") end
      Wow.loadAddon(helper)

      env.fire("ADDON_LOADED", "IntroVert")

      assert.equal(1, #env.errors)
      assert.is_true(env.printed("Options panel could not be built"))
    end)

    it("skips the panel when the Settings API is missing", function()
      Wow.uninstall()
      env = Wow.install()
      _G.Settings = nil
      Wow.loadAddon(helper)

      env.fire("ADDON_LOADED", "IntroVert")

      assert.equal(0, #env.errors)
      assert.is_true(env.printed("Options panel is not available"))
    end)
  end)

  describe("values", function()
    it("reads the current saved value", function()
      ns.UpdateSetting({ "quiet", "chatLevel", "lfr" }, "all")

      assert.equal("all", setting("quiet_chatLevel_lfr"):GetValue())
    end)

    it("saves a changed value as a new settings table", function()
      local before = ns.db

      setting("quiet_greet"):SetValue(false)

      assert.is_false(IntroVertDB.quiet.greet)
      assert.is_true(before.quiet.greet)
    end)

    it("applies a toggle immediately while in a group", function()
      enterDungeon()
      assert.is_true(env.chat("CHAT_MSG_INSTANCE_CHAT", "go go", "Stranger-Realm", 1))

      setting("quiet_enabled_dungeon"):SetValue(false)

      assert.is_false(env.chat("CHAT_MSG_INSTANCE_CHAT", "go go", "Stranger-Realm", 2))
    end)

    it("shows slash command changes in the panel", function()
      env.slash("quiet dungeon leader")

      assert.equal("leader", setting("quiet_chatLevel_dungeon"):GetValue())
    end)
  end)

  describe("list editors", function()
    it("opens the keyword editor with the current list", function()
      button("Keywords").onClick()

      assert.equal("wait, afk, kick, brb", env.popup.editBox:GetText())
    end)

    it("saves the edited list on accept", function()
      button("Greetings").onClick()

      env.acceptPopup("hello, o/ , hello")

      assert.same({ "hello", "o/" }, IntroVertDB.quiet.greetings)
    end)

    it("saves on Enter too", function()
      button("Goodbyes").onClick()

      env.enterPopup("cya")

      assert.same({ "cya" }, IntroVertDB.quiet.farewells)
      assert.is_false(env.popup.shown)
    end)

    it("closes without saving on Escape", function()
      button("Keywords").onClick()

      env.escapePopup()

      assert.is_false(env.popup.shown)
      assert.same({ "wait", "afk", "kick", "brb" }, IntroVertDB.quiet.keywords)
    end)

    it("uses new keywords for filtering right away", function()
      button("Keywords").onClick()
      env.acceptPopup("loot")
      enterDungeon()

      assert.is_false(env.chat("CHAT_MSG_INSTANCE_CHAT", "need loot", "Stranger-Realm", 1))
      assert.is_true(env.chat("CHAT_MSG_INSTANCE_CHAT", "wait", "Stranger-Realm", 2))
    end)
  end)

  describe("/iv options", function()
    it("opens the introVert category", function()
      env.slash("options")

      assert.equal(env.settings.categories[1]:GetID(), env.settings.opened)
    end)

    it("also answers to /iv config", function()
      env.slash("config")

      assert.is_not_nil(env.settings.opened)
    end)

    it("refuses to open during combat", function()
      env.inCombat = true

      env.slash("options")

      assert.is_nil(env.settings.opened)
      assert.is_true(env.printed("after combat"))
    end)

    it("is listed in /iv help", function()
      env.slash("help")

      assert.is_true(env.printed("/iv options"))
    end)

    it("explains when the panel is unavailable", function()
      Wow.uninstall()
      env = Wow.install()
      _G.Settings = nil
      Wow.loadAddon(helper)
      env.fire("ADDON_LOADED", "IntroVert")

      env.slash("options")

      assert.is_true(env.printed("Options panel is not available"))
    end)
  end)
end)
