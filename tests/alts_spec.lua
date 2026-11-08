local helper = require("tests.helper")

local HOUR = 3600
local DAY = 24 * HOUR
local NOW = 1000000
local LAST_RESET = NOW - DAY

describe("Alts", function()
  local Alts

  before_each(function()
    Alts = helper.loadPure({ "Modules/Raids/Lockouts.lua", "Modules/Alts/Alts.lua" }).Alts
  end)

  describe("vaultSummary", function()
    local types = { raid = 3, dungeon = 1, world = 6 }

    it("counts finished slots per row", function()
      local activities = {
        { type = 3, progress = 2, threshold = 2 },
        { type = 3, progress = 2, threshold = 4 },
        { type = 1, progress = 0, threshold = 1 },
        { type = 6, progress = 8, threshold = 2 },
        { type = 6, progress = 8, threshold = 4 },
        { type = 6, progress = 8, threshold = 8 },
        { type = 2, progress = 9, threshold = 1 },
      }

      assert.same({ raid = 1, dungeon = 0, world = 3 }, Alts.vaultSummary(activities, types))
    end)

    it("returns zeros without activities", function()
      assert.same({ raid = 0, dungeon = 0, world = 0 }, Alts.vaultSummary(nil, types))
    end)
  end)

  describe("formatGold", function()
    it("shows whole gold with thousands separators", function()
      assert.equal("12,345g", Alts.formatGold(123456789))
      assert.equal("0g", Alts.formatGold(9999))
      assert.equal("1,000,000g", Alts.formatGold(10000000000))
    end)
  end)

  describe("lines", function()
    local alts = {
      ["Nubbel-Silvermoon"] = {
        level = 90, race = "Dwarf", class = "Rogue", itemLevel = 712, gold = 123456789, hasRewards = false,
        vault = { raid = 1, dungeon = 0, world = 3 }, updatedAt = NOW,
      },
      ["Palanore-Silvermoon"] = {
        level = 90, itemLevel = 650, gold = 5000000, hasRewards = true,
        vault = { raid = 3, dungeon = 3, world = 3 }, updatedAt = NOW - 2 * DAY - 4 * HOUR,
      },
    }

    it("shows each character with vault, rewards, gold and last seen", function()
      local lines = Alts.lines(alts, NOW, LAST_RESET, "Nubbel-Silvermoon")

      assert.same({
        "Nubbel-Silvermoon (90 Dwarf Rogue, ilvl 712) - online",
        "  Vault: raid 1/3, dungeons 0/3, world 3/3",
        "  Gold: 12,345g",
        "Palanore-Silvermoon (90, ilvl 650) - seen 2d 4h ago",
        "  Vault: reset since last seen",
        "  Rewards waiting in the Great Vault",
        "  Gold: 500g",
        "Total gold: 12,845g",
      }, lines)
    end)

    it("says when the vault could not be read", function()
      local lines = Alts.lines({ ["A-R"] = { level = 1, itemLevel = 1, gold = 0, updatedAt = NOW } }, NOW, LAST_RESET, "A-R")

      assert.equal("  Vault: not available", lines[2])
    end)

    it("explains when no character is recorded", function()
      assert.same({ "No characters recorded yet. Log in on each character once." }, Alts.lines({}, NOW, LAST_RESET, "x"))
    end)
  end)
end)
