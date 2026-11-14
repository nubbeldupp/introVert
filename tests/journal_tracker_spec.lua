local helper = require("tests.helper")
local Wow = require("tests.support.wow")

local GOLD = 10000
local KEY = "Nubbel-Silvermoon"

describe("Session journal", function()
  local env, ns

  local function windowHas(text)
    return (ns.Window.GetText() or ""):find(text, 1, true) ~= nil
  end

  local function sessions()
    return IntroVertDB.journal.sessions
  end

  local function entryTexts()
    local texts = {}
    for index, entry in ipairs(sessions()[1].entries) do
      texts[index] = entry.text
    end
    return texts
  end

  local function login()
    env.fire("PLAYER_ENTERING_WORLD", true, false)
  end

  local function reload()
    env.fire("PLAYER_ENTERING_WORLD", false, true)
  end

  before_each(function()
    env = Wow.install()
    env.money = 100 * GOLD
    env.mounts = { [50818] = { mountID = 363, name = "Invincible", collected = false } }
    env.achievementCategories = {
      { id = 96, title = "Quests", parent = -1, achievements = {
        { id = 1, name = "Anvil Mastery II", points = 10, completed = true, reward = "", isGuild = false, criteria = {} },
      } },
    }
    ns = Wow.loadAddon(helper)
    ns.RaidMountData = { raids = {
      { instanceID = 631, name = "Icecrown Citadel", minutes = 20, mounts = { { itemID = 50818, boss = "The Lich King" } } },
    } }
    env.fire("ADDON_LOADED", "IntroVert")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  describe("sessions", function()
    it("starts a session on login and keeps it on reload", function()
      login()
      assert.equal(1, #sessions())
      assert.equal(KEY, sessions()[1].character)
      assert.equal(100 * GOLD, sessions()[1].startGold)

      reload()
      assert.equal(1, #sessions())

      login()
      assert.equal(2, #sessions())
    end)

    it("starts a session on reload when none exists yet", function()
      reload()

      assert.equal(1, #sessions())
    end)

    it("ignores events before any session exists", function()
      env.fire("PLAYER_MONEY")

      assert.same({}, sessions())
    end)

    it("records the time on logout", function()
      login()
      env.time = env.time + 600

      env.fire("PLAYER_LOGOUT")

      assert.equal(env.time, sessions()[1].updatedAt)
    end)
  end)

  describe("logging", function()
    before_each(login)

    it("logs raid boss kills and the mount attempts they count", function()
      env.instance = { inInstance = true, instanceType = "raid", difficultyID = 6, instanceID = 631, name = "Icecrown Citadel" }

      env.fire("ENCOUNTER_END", 1, "The Lich King", 6, 25, 1)

      assert.same({ boss = 1, attempt = 1 }, sessions()[1].counts)
      assert.same({ "Mount attempt 1: Invincible", "Boss: The Lich King (Icecrown Citadel)" }, entryTexts())
    end)

    it("logs dungeon boss kills but not wipes or kills elsewhere", function()
      env.instance = { inInstance = true, instanceType = "party", difficultyID = 1, instanceID = 329, name = "Stratholme" }
      env.fire("ENCOUNTER_END", 1, "Lord Aurius Rivendare", 1, 5, 1)
      env.fire("ENCOUNTER_END", 1, "Lord Aurius Rivendare", 1, 5, 0)
      env.instance = { inInstance = true, instanceType = "scenario", difficultyID = 208, instanceID = 1, name = "Delve" }
      env.fire("ENCOUNTER_END", 1, "Delve Boss", 208, 1, 1)

      assert.same({ "Boss: Lord Aurius Rivendare (Stratholme)" }, entryTexts())
    end)

    it("logs finished delves and Labyrinth chambers", function()
      env.instance = { inInstance = true, instanceType = "scenario", difficultyID = 208, difficultyName = "Delves",
        instanceID = 1, name = "Fungal Folly" }
      env.fire("SCENARIO_COMPLETED")
      env.instance = { inInstance = true, instanceType = "scenario", difficultyID = 208, difficultyName = "Delves",
        instanceID = 3043, name = "The Labyrinth of Kindo'jan" }
      env.fire("SCENARIO_COMPLETED")

      assert.same({ delve = 1, chamber = 1 }, sessions()[1].counts)
      assert.same({ "Delve: Fungal Folly, tier ?", "Labyrinth chamber 1, tier ?" }, entryTexts())
    end)

    it("logs newly earned achievements only", function()
      env.fire("ACHIEVEMENT_EARNED", 1, false)
      env.fire("ACHIEVEMENT_EARNED", 1, true)

      assert.same({ "Achievement: Anvil Mastery II" }, entryTexts())
    end)

    it("follows the gold", function()
      env.money = 150 * GOLD

      env.fire("PLAYER_MONEY")

      assert.equal(150 * GOLD, sessions()[1].gold)
    end)
  end)

  describe("login summary", function()
    it("prints what the last session achieved", function()
      login()
      env.fire("ACHIEVEMENT_EARNED", 1, false)
      env.money = 150 * GOLD
      env.fire("PLAYER_MONEY")

      login()

      assert.is_true(env.printed("Last session"))
      assert.is_true(env.printed("1 achievement, +50g"))
    end)

    it("stays quiet after a session with nothing in it", function()
      login()

      login()

      assert.is_false(env.printed("Last session"))
    end)

    it("can be switched off in the options", function()
      login()
      env.fire("ACHIEVEMENT_EARNED", 1, false)
      env.settings.byVariable["IntroVert_journal_loginSummary"]:SetValue(false)

      login()

      assert.is_false(env.printed("Last session"))
    end)
  end)

  describe("Journal tab", function()
    it("/iv journal opens it with this session", function()
      login()
      env.fire("ACHIEVEMENT_EARNED", 1, false)

      env.slash("journal")

      assert.equal("journal", ns.Window.CurrentView())
      assert.is_true(windowHas("This session: " .. KEY))
      assert.is_true(windowHas("Achievement: Anvil Mastery II"))
    end)

    it("refreshes while open", function()
      login()
      env.slash("journal")

      env.fire("ACHIEVEMENT_EARNED", 1, false)

      assert.is_true(windowHas("Achievement: Anvil Mastery II"))
    end)

    it("is listed in /iv help", function()
      env.slash("help")

      assert.is_true(env.printed("/iv journal"))
    end)
  end)
end)
