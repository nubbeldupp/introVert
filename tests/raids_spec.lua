local helper = require("tests.helper")
local Wow = require("tests.support.wow")

local DAY = 24 * 3600

describe("Raid lockout tracker", function()
  local env, ns

  local function windowHas(text)
    return (ns.Window.GetText() or ""):find(text, 1, true) ~= nil
  end

  local function raid(name, overrides)
    local base = {
      name = name, reset = 2 * DAY, difficultyID = 14, difficultyName = "Normal",
      locked = true, extended = false, isRaid = true, numEncounters = 8, encounterProgress = 3,
      instanceID = 1,
    }
    for key, value in pairs(overrides or {}) do
      base[key] = value
    end
    return base
  end

  local function myLockouts()
    return IntroVertDB.characters["Nubbel-Silvermoon"].lockouts
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
    it("asks the server for lockouts on login", function()
      env.fire("PLAYER_ENTERING_WORLD")

      assert.equal(1, env.raidInfoRequests)
    end)

    it("stores the current character's raid lockouts", function()
      env.savedInstances = { raid("Ulduar"), raid("Halls of Stone", { isRaid = false }) }

      env.fire("UPDATE_INSTANCE_INFO")

      assert.equal(1, #myLockouts())
      assert.equal("Ulduar", myLockouts()[1].name)
      assert.equal(env.time + 2 * DAY, myLockouts()[1].expiresAt)
      assert.equal(env.time, IntroVertDB.characters["Nubbel-Silvermoon"].updatedAt)
    end)

    it("replaces old data for the same character", function()
      env.savedInstances = { raid("Ulduar") }
      env.fire("UPDATE_INSTANCE_INFO")
      env.savedInstances = {}

      env.fire("UPDATE_INSTANCE_INFO")

      assert.same({}, myLockouts())
    end)

    it("refreshes after a raid boss kill", function()
      env.instance = { inInstance = true, instanceType = "raid", difficultyID = 14 }

      env.fire("ENCOUNTER_END", 1, "Boss", 14, 10, 1)

      assert.equal(1, env.raidInfoRequests)
    end)

    it("does not refresh after a wipe or a dungeon boss", function()
      env.instance = { inInstance = true, instanceType = "raid", difficultyID = 14 }
      env.fire("ENCOUNTER_END", 1, "Boss", 14, 10, 0)
      env.instance = { inInstance = true, instanceType = "party", difficultyID = 2 }
      env.fire("ENCOUNTER_END", 1, "Boss", 2, 5, 1)

      assert.equal(0, env.raidInfoRequests)
    end)
  end)

  describe("/iv raids", function()
    it("explains in the window when nothing is recorded yet", function()
      env.slash("raids")

      assert.is_true(windowHas("No lockouts recorded yet"))
    end)

    it("explains in chat when a raid is queried before anything is recorded", function()
      env.slash("raids ulduar")

      assert.is_true(env.printed("No lockouts recorded yet"))
    end)

    it("lists every known character in the window", function()
      env.savedInstances = { raid("Ulduar") }
      env.fire("UPDATE_INSTANCE_INFO")
      _G.IntroVertDB.characters["Alt-Silvermoon"] = { lockouts = {}, updatedAt = env.time }

      env.slash("raids")

      assert.is_true(windowHas("Alt-Silvermoon|r\n  no active raid lockouts"))
      assert.is_true(windowHas("Nubbel-Silvermoon|r\n  Ulduar (Normal) 3/8, resets in 2d 0h"))
    end)

    it("hides lockouts that have reset since they were recorded", function()
      env.savedInstances = { raid("Ulduar") }
      env.fire("UPDATE_INSTANCE_INFO")
      env.time = env.time + 3 * DAY

      env.slash("raids")

      assert.is_true(windowHas("Nubbel-Silvermoon|r\n  no active raid lockouts"))
    end)

    it("shows locked and free characters for one raid", function()
      env.savedInstances = { raid("Ulduar") }
      env.fire("UPDATE_INSTANCE_INFO")
      _G.IntroVertDB.characters["Alt-Silvermoon"] = { lockouts = {}, updatedAt = env.time }

      env.slash("raids ulduar")

      assert.is_true(env.printed("Locked: Nubbel-Silvermoon: Ulduar"))
      assert.is_true(env.printed("Free: Alt-Silvermoon"))
    end)

    it("says when every character is locked", function()
      env.savedInstances = { raid("Ulduar") }
      env.fire("UPDATE_INSTANCE_INFO")

      env.slash("raids ulduar")

      assert.is_true(env.printed("Free: none"))
    end)

    it("forgets a deleted character", function()
      _G.IntroVertDB.characters["Alt-Silvermoon"] = { lockouts = {}, updatedAt = env.time }

      env.slash("raids forget alt-silvermoon")

      assert.is_nil(IntroVertDB.characters["Alt-Silvermoon"])
      assert.is_true(env.printed("Forgot Alt-Silvermoon"))
    end)

    it("reports an unknown character to forget", function()
      env.slash("raids forget Nobody-Nowhere")

      assert.is_true(env.printed("No saved character named 'Nobody-Nowhere'"))
    end)

    it("is listed in /iv help", function()
      env.slash("help")

      assert.is_true(env.printed("/iv raids <name>"))
      assert.is_true(env.printed("/iv raids forget <Name-Realm>"))
    end)
  end)
end)
