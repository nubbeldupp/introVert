local helper = require("tests.helper")
local Wow = require("tests.support.wow")

describe("Delve tracker", function()
  local env, ns

  local function windowHas(text)
    return (ns.Window.GetText() or ""):find(text, 1, true) ~= nil
  end

  local function inDelve(name, tierName)
    env.instance = {
      inInstance = true, instanceType = "scenario", difficultyID = 208,
      name = name, difficultyName = tierName,
    }
  end

  before_each(function()
    env = Wow.install()
    ns = Wow.loadAddon(helper)
    env.fire("ADDON_LOADED", "IntroVert")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  describe("recording", function()
    it("records a finished delve with its tier", function()
      inDelve("Fungal Folly", "Tier 8")

      env.fire("SCENARIO_COMPLETED")

      assert.same({ runs = 1, bestTier = 8, lastAt = env.time }, IntroVertDB.delves["Fungal Folly"])
      assert.is_true(env.printed("Delve recorded: Fungal Folly, tier 8."))
    end)

    it("keeps the best tier over several runs", function()
      inDelve("Fungal Folly", "Tier 8")
      env.fire("SCENARIO_COMPLETED")
      inDelve("Fungal Folly", "Tier 3")

      env.fire("SCENARIO_COMPLETED")

      assert.equal(8, IntroVertDB.delves["Fungal Folly"].bestTier)
      assert.equal(2, IntroVertDB.delves["Fungal Folly"].runs)
    end)

    it("ignores scenarios that are not delves", function()
      env.instance = { inInstance = true, instanceType = "scenario", difficultyID = 12, name = "Other" }

      env.fire("SCENARIO_COMPLETED")

      assert.same({}, IntroVertDB.delves)
    end)

    it("shows a question mark when the tier is unknown", function()
      inDelve("Story Delve", "Story")

      env.fire("SCENARIO_COMPLETED")

      assert.is_true(env.printed("Delve recorded: Story Delve, tier ?."))
    end)

    describe("tier from the delve tracker widget", function()
      local function showTierWidget(tierText)
        env.scenarioWidgetSet = 842
        env.widgets = { [842] = { 6100, 6183 } }
        env.widgetTiers = { [6183] = tierText }
      end

      local function hideTierWidget()
        env.scenarioWidgetSet = 0
      end

      it("captures the tier during the delve and uses it on completion", function()
        inDelve("The Darkway", "Delves")
        showTierWidget("11")
        env.fire("SCENARIO_UPDATE")
        hideTierWidget()

        env.fire("SCENARIO_COMPLETED")

        assert.equal(11, IntroVertDB.delves["The Darkway"].bestTier)
        assert.is_true(env.printed("Delve recorded: The Darkway, tier 11."))
      end)

      it("reads the widget at completion when nothing was captured", function()
        inDelve("The Darkway", "Delves")
        showTierWidget("Tier 9")

        env.fire("SCENARIO_COMPLETED")

        assert.equal(9, IntroVertDB.delves["The Darkway"].bestTier)
      end)

      it("forgets the captured tier after leaving the delve", function()
        inDelve("The Darkway", "Delves")
        showTierWidget("11")
        env.fire("SCENARIO_CRITERIA_UPDATE")
        env.instance = { inInstance = false, instanceType = "none", difficultyID = 0 }
        env.fire("PLAYER_ENTERING_WORLD")
        hideTierWidget()
        inDelve("Other Delve", "Delves")

        env.fire("SCENARIO_COMPLETED")

        assert.is_true(env.printed("Delve recorded: Other Delve, tier ?."))
      end)

      it("falls back quietly when the widget API is missing", function()
        _G.C_UIWidgetManager = nil
        inDelve("Fungal Folly", "Tier 8")
        env.fire("SCENARIO_UPDATE")

        env.fire("SCENARIO_COMPLETED")

        assert.equal(8, IntroVertDB.delves["Fungal Folly"].bestTier)
        assert.equal(0, #env.errors)
      end)
    end)
  end)

  describe("Labyrinth of Kindo'jan", function()
    local NAME = "The Labyrinth of Kindo'jan"

    local function inLabyrinth()
      env.instance = {
        inInstance = true, instanceType = "scenario", difficultyID = 208,
        name = NAME, difficultyName = "Delves", instanceID = 3043,
      }
      env.scenarioWidgetSet = 842
      env.widgets = { [842] = { 6183 } }
      env.widgetTiers = { [6183] = "1" }
    end

    local function clearChamber()
      env.fire("SCENARIO_UPDATE")
      env.fire("SCENARIO_COMPLETED")
    end

    it("counts each chamber instead of a run", function()
      inLabyrinth()

      clearChamber()
      clearChamber()

      assert.same(
        { labyrinth = true, chambers = 2, bestTier = 1, bestVisit = 2, lastAt = env.time },
        IntroVertDB.delves[NAME]
      )
      assert.is_true(env.printed("Labyrinth: chamber cleared (2 this visit), tier 1."))
    end)

    it("starts a new visit after leaving", function()
      inLabyrinth()
      clearChamber()
      clearChamber()
      env.instance = { inInstance = false, instanceType = "none", difficultyID = 0 }
      env.fire("PLAYER_ENTERING_WORLD")
      inLabyrinth()

      clearChamber()

      assert.equal(3, IntroVertDB.delves[NAME].chambers)
      assert.equal(2, IntroVertDB.delves[NAME].bestVisit)
      assert.is_true(env.printed("Labyrinth: chamber cleared (1 this visit), tier 1."))
    end)

    it("shows chambers in the Delves tab", function()
      inLabyrinth()
      clearChamber()

      env.slash("delves")

      assert.is_true(windowHas("The Labyrinth of Kindo'jan - best tier 1, 1 chamber, best visit 1/9"))
    end)

    it("leaves normal delves counting runs", function()
      inDelve("Fungal Folly", "Tier 8")

      env.fire("SCENARIO_COMPLETED")

      assert.equal(1, IntroVertDB.delves["Fungal Folly"].runs)
      assert.is_nil(IntroVertDB.delves["Fungal Folly"].labyrinth)
    end)
  end)

  describe("Delves tab", function()
    before_each(function()
      env.vault = {
        { index = 1, threshold = 2, progress = 2, level = 8 },
        { index = 2, threshold = 4, progress = 2, level = 0 },
      }
      env.zones = { { mapID = 2248, name = "Isle of Dorn" }, { mapID = 2249, name = "Isle of Dorn (sub)" } }
      env.delvePois = {
        [2248] = {
          { poiID = 1, name = "Fungal Folly", atlasName = "delves-bountiful" },
          { poiID = 2, name = "Earthcrawl Mines", atlasName = "delves-regular" },
        },
        [2249] = { { poiID = 1, name = "Fungal Folly", atlasName = "delves-bountiful" } },
      }
    end)

    it("/iv delves opens the tab with vault, bountiful and history", function()
      inDelve("Fungal Folly", "Tier 8")
      env.fire("SCENARIO_COMPLETED")

      env.slash("delves")

      assert.equal("delves", ns.Window.CurrentView())
      assert.is_true(windowHas("Slot 1: done (2/2), level 8"))
      assert.is_true(windowHas("Slot 2: 2/4, 2 more"))
      assert.is_true(windowHas("  Fungal Folly (Isle of Dorn)"))
      assert.is_false(windowHas("Earthcrawl Mines"))
      assert.is_true(windowHas("Fungal Folly - best tier 8, 1 run"))
    end)

    it("lists a bountiful delve only once even if two maps show it", function()
      env.slash("delves")

      local _, count = ns.Window.GetText():gsub("Fungal Folly %(", "")
      assert.equal(1, count)
    end)

    it("shows a section as unavailable when its game API fails", function()
      _G.C_WeeklyRewards.GetActivities = function() error("api changed") end

      env.slash("delves")

      assert.is_true(windowHas("This week (Great Vault, world activities)|r\n  Not available on this client."))
      assert.is_true(windowHas("Bountiful delves today"))
    end)

    it("shows a section as unavailable when its game API is missing", function()
      _G.C_AreaPoiInfo = nil

      env.slash("delves")

      assert.is_true(windowHas("Bountiful delves today|r\n  Not available on this client."))
    end)

    it("redraws when the vault updates", function()
      env.slash("delves")
      env.vault[2].progress = 3

      env.fire("WEEKLY_REWARDS_UPDATE")

      assert.is_true(windowHas("Slot 2: 3/4, 1 more"))
    end)

    it("is listed in /iv help", function()
      env.slash("help")

      assert.is_true(env.printed("/iv delves"))
    end)
  end)
end)
