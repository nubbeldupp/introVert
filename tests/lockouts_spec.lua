local helper = require("tests.helper")

local HOUR = 3600
local DAY = 24 * HOUR
local NOW = 1000000

describe("Raid lockouts", function()
  local Lockouts

  before_each(function()
    Lockouts = helper.loadPure({ "Modules/Raids/Lockouts.lua" }).RaidLockouts
  end)

  local function entry(overrides)
    local base = {
      name = "Ulduar", reset = 2 * DAY, difficultyName = "10 Player", locked = true,
      extended = false, isRaid = true, numEncounters = 14, encounterProgress = 14,
    }
    for key, value in pairs(overrides or {}) do
      base[key] = value
    end
    return base
  end

  local function lockout(name, expiresAt, difficultyName)
    return { name = name, difficultyName = difficultyName or "Normal", progress = 3, total = 8, expiresAt = expiresAt }
  end

  describe("fromSaved", function()
    it("keeps locked raids with an absolute expiry time", function()
      local result = Lockouts.fromSaved({ entry() }, NOW)

      assert.same({
        { name = "Ulduar", difficultyName = "10 Player", progress = 14, total = 14, expiresAt = NOW + 2 * DAY },
      }, result)
    end)

    it("keeps extended lockouts", function()
      assert.equal(1, #Lockouts.fromSaved({ entry({ locked = false, extended = true }) }, NOW))
    end)

    it("drops dungeons and expired entries", function()
      local result = Lockouts.fromSaved({
        entry({ isRaid = false }),
        entry({ locked = false, extended = false }),
      }, NOW)

      assert.same({}, result)
    end)

    it("sorts by raid name", function()
      local result = Lockouts.fromSaved({ entry({ name = "Ulduar" }), entry({ name = "Karazhan" }) }, NOW)

      assert.equal("Karazhan", result[1].name)
    end)
  end)

  describe("active", function()
    it("drops lockouts that already reset", function()
      local result = Lockouts.active({ lockout("Old", NOW - 1), lockout("New", NOW + 1) }, NOW)

      assert.equal(1, #result)
      assert.equal("New", result[1].name)
    end)

    it("handles a missing list", function()
      assert.same({}, Lockouts.active(nil, NOW))
    end)
  end)

  describe("formatDuration", function()
    it("uses days and hours for long waits", function()
      assert.equal("2d 4h", Lockouts.formatDuration(2 * DAY + 4 * HOUR + 59))
    end)

    it("uses hours and minutes under a day", function()
      assert.equal("3h 12m", Lockouts.formatDuration(3 * HOUR + 12 * 60))
    end)

    it("uses minutes under an hour", function()
      assert.equal("45m", Lockouts.formatDuration(45 * 60 + 30))
    end)

    it("never goes below one minute", function()
      assert.equal("1m", Lockouts.formatDuration(5))
    end)
  end)

  describe("characterLines", function()
    local characters = {
      ["Zed-Realm"] = { lockouts = { lockout("Ulduar", NOW + DAY) } },
      ["Abe-Realm"] = { lockouts = { lockout("Karazhan", NOW - 1) } },
    }

    it("lists characters alphabetically with active lockouts", function()
      local lines = Lockouts.characterLines(characters, NOW)

      assert.same({
        "Abe-Realm: no active raid lockouts",
        "Zed-Realm: Ulduar (Normal) 3/8, resets in 1d 0h",
      }, lines)
    end)

    it("returns nothing when no characters are known", function()
      assert.same({}, Lockouts.characterLines({}, NOW))
    end)
  end)

  describe("forRaid", function()
    local characters = {
      ["Abe-Realm"] = { lockouts = { lockout("Icecrown Citadel", NOW + DAY, "Heroic") } },
      ["Bob-Realm"] = { lockouts = { lockout("Icecrown Citadel", NOW - 1) } },
      ["Cid-Realm"] = { lockouts = {} },
    }

    it("splits characters into locked and free, case-insensitive", function()
      local result = Lockouts.forRaid(characters, "icecrown", NOW)

      assert.same({ "Abe-Realm: Icecrown Citadel (Heroic) 3/8, resets in 1d 0h" }, result.locked)
      assert.same({ "Bob-Realm", "Cid-Realm" }, result.free)
    end)

    it("treats the query as plain text", function()
      local result = Lockouts.forRaid(characters, "ice.", NOW)

      assert.same({}, result.locked)
    end)
  end)
end)
