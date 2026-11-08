local helper = require("tests.helper")
local Wow = require("tests.support.wow")

local TEST_DATA = {
  raids = {
    {
      instanceID = 631, name = "Icecrown Citadel",
      mounts = { { itemID = 50818, boss = "The Lich King", difficulties = { 6 } } },
    },
    {
      instanceID = 603, name = "Ulduar",
      mounts = { { itemID = 45693, boss = "Yogg-Saron" } },
    },
  },
}

describe("Mount tracker", function()
  local env, ns

  local function inRaid(instanceID, difficultyID)
    env.instance = { inInstance = true, instanceType = "raid", difficultyID = difficultyID, instanceID = instanceID }
  end

  before_each(function()
    env = Wow.install()
    env.mounts = {
      [50818] = { mountID = 363, name = "Invincible", collected = false },
      [45693] = { mountID = 304, name = "Mimiron's Head", collected = true },
    }
    ns = Wow.loadAddon(helper)
    ns.RaidMountData = TEST_DATA
    env.fire("ADDON_LOADED", "IntroVert")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  describe("attempts", function()
    it("counts a kill of the right boss on the right difficulty", function()
      inRaid(631, 6)

      env.fire("ENCOUNTER_END", 1, "The Lich King", 6, 25, 1)

      assert.equal(1, IntroVertDB.attempts[50818])
      assert.is_true(env.printed("Attempt 1 for Invincible"))
    end)

    it("keeps counting across kills", function()
      inRaid(631, 6)
      env.fire("ENCOUNTER_END", 1, "The Lich King", 6, 25, 1)

      env.fire("ENCOUNTER_END", 1, "The Lich King", 6, 25, 1)

      assert.equal(2, IntroVertDB.attempts[50818])
    end)

    it("ignores wipes and the wrong difficulty", function()
      inRaid(631, 6)
      env.fire("ENCOUNTER_END", 1, "The Lich King", 6, 25, 0)
      inRaid(631, 4)
      env.fire("ENCOUNTER_END", 1, "The Lich King", 4, 25, 1)

      assert.is_nil(IntroVertDB.attempts[50818])
    end)

    it("does not count mounts you already own", function()
      inRaid(603, 3)

      env.fire("ENCOUNTER_END", 1, "Yogg-Saron", 3, 10, 1)

      assert.is_nil(IntroVertDB.attempts[45693])
    end)

    it("ignores kills outside raids", function()
      env.instance = { inInstance = true, instanceType = "party", difficultyID = 6, instanceID = 631 }

      env.fire("ENCOUNTER_END", 1, "The Lich King", 6, 5, 1)

      assert.is_nil(IntroVertDB.attempts[50818])
    end)
  end)

  describe("/iv mounts", function()
    it("lists missing mounts with attempts and free characters", function()
      inRaid(631, 6)
      env.fire("ENCOUNTER_END", 1, "The Lich King", 6, 25, 1)
      env.fire("UPDATE_INSTANCE_INFO")

      env.slash("mounts")

      assert.is_true(env.printed("Icecrown Citadel - free: Nubbel-Silvermoon"))
      assert.is_true(env.printed("Invincible - The Lich King, 1 attempt"))
      assert.is_true(env.printed("Collected 1 of 2 tracked raid mounts."))
    end)

    it("lists unrecognised items with check", function()
      env.mounts[45693] = nil

      env.slash("mounts check")

      assert.is_true(env.printed("Not a known mount: item 45693 (Ulduar, Yogg-Saron)"))
    end)

    it("confirms when every item is recognised", function()
      env.slash("mounts check")

      assert.is_true(env.printed("All 2 tracked items are known mounts."))
    end)

    it("asks the client to load every tracked item at startup", function()
      assert.same({ [50818] = true, [45693] = true }, env.itemLoadRequests)
    end)

    it("reports uncached items as loading, not as wrong", function()
      env.uncachedItems = { [50818] = true }

      env.slash("mounts")

      assert.is_true(env.printed("Still loading 1 mounts"))
      assert.is_false(env.printed("Invincible"))
    end)

    it("check waits for uncached items before calling them wrong", function()
      env.uncachedItems = { [45693] = true }
      env.mounts[45693] = nil

      env.slash("mounts check")

      assert.is_true(env.printed("1 items are still loading"))
      assert.is_false(env.printed("Not a known mount"))
    end)

    it("is listed in /iv help", function()
      env.slash("help")

      assert.is_true(env.printed("/iv mounts - missing raid mounts"))
      assert.is_true(env.printed("/iv mounts check"))
    end)
  end)
end)
