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
  dungeons = {
    {
      instanceID = 329, name = "Stratholme",
      mounts = { { itemID = 13335, boss = "Lord Aurius Rivendare" } },
    },
  },
}

describe("Mount tracker", function()
  local env, ns

  local function windowHas(text)
    return (ns.Window.GetText() or ""):find(text, 1, true) ~= nil
  end

  local function inRaid(instanceID, difficultyID)
    env.instance = { inInstance = true, instanceType = "raid", difficultyID = difficultyID, instanceID = instanceID }
  end

  before_each(function()
    env = Wow.install()
    env.mounts = {
      [50818] = { mountID = 363, name = "Invincible", collected = false },
      [45693] = { mountID = 304, name = "Mimiron's Head", collected = true },
      [13335] = { mountID = 69, name = "Deathcharger", collected = false },
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
      assert.is_true(env.printed("Attempt 1 for Invincible (1% drop: 1% of players would have it by now)."))
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

    it("ignores kills outside raids and dungeons", function()
      env.instance = { inInstance = true, instanceType = "scenario", difficultyID = 6, instanceID = 631 }

      env.fire("ENCOUNTER_END", 1, "The Lich King", 6, 5, 1)

      assert.is_nil(IntroVertDB.attempts[50818])
    end)

    it("counts dungeon boss kills", function()
      env.instance = { inInstance = true, instanceType = "party", difficultyID = 1, instanceID = 329 }

      env.fire("ENCOUNTER_END", 1, "Lord Aurius Rivendare", 1, 5, 1)

      assert.equal(1, IntroVertDB.attempts[13335])
      assert.is_true(env.printed("Attempt 1 for Deathcharger"))
    end)
  end)

  describe("class colours", function()
    it("colours opened character names by class, also for alts recorded before classFile existed", function()
      _G.IntroVertDB.characters = {
        ["Lock-Silvermoon"] = { lockouts = {} },
        ["Old-Silvermoon"] = { lockouts = {} },
        ["Unknown-Silvermoon"] = { lockouts = {} },
      }
      _G.IntroVertDB.alts = {
        ["Lock-Silvermoon"] = { classFile = "WARLOCK" },
        ["Old-Silvermoon"] = { class = "Rogue" },
      }
      env.slash("mounts")

      ns.Window.ClickLink("introvert:toggle:50818")

      assert.is_true(windowHas("    |cff8788eeLock|r - free"))
      assert.is_true(windowHas("    |cfffff468Old|r - free"))
      assert.is_true(windowHas("    Unknown - free"))
    end)
  end)

  describe("/iv mounts", function()
    it("lists missing mounts as clickable rows with attempts and a status line", function()
      inRaid(631, 6)
      env.fire("ENCOUNTER_END", 1, "The Lich King", 6, 25, 1)
      env.fire("UPDATE_INSTANCE_INFO")

      env.slash("mounts")

      assert.is_true(windowHas("|Hintrovert:toggle:50818|h[+] Invincible - The Lich King, 1 attempt|h"))
      assert.is_true(windowHas("\n  Icecrown Citadel: free\n"))
      assert.is_true(windowHas("Collected 1 of 3 tracked mounts."))
      assert.is_true(windowHas("Dungeon mounts|r\n|cffffd100Deathcharger - Lord Aurius Rivendare, 0 attempts|r"))
      assert.is_true(windowHas("\n  Stratholme: no lockout, farm any time"))
    end)

    it("lists unrecognised items with check", function()
      env.mounts[45693] = nil

      env.slash("mounts check")

      assert.is_true(env.printed("Not a known mount: item 45693 (Ulduar, Yogg-Saron)"))
    end)

    it("confirms when every item is recognised", function()
      env.slash("mounts check")

      assert.is_true(env.printed("All 3 tracked items are known mounts."))
    end)

    it("asks the client to load every tracked raid and dungeon item at startup", function()
      assert.same({ [50818] = true, [45693] = true, [13335] = true }, env.itemLoadRequests)
    end)

    it("reports uncached items as loading, not as wrong", function()
      env.uncachedItems = { [50818] = true }

      env.slash("mounts")

      assert.is_true(windowHas("Still loading 1 mounts"))
      assert.is_false(windowHas("Invincible"))
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

      assert.is_true(env.printed("/iv mounts - missing raid and dungeon mounts"))
      assert.is_true(env.printed("/iv mounts check"))
      assert.is_true(env.printed("/iv mounts set <mount> <count>"))
    end)
  end)

  describe("/iv mounts set", function()
    it("sets the attempt count for a mount by name", function()
      env.slash("mounts set Invincible 12")

      assert.equal(12, IntroVertDB.attempts[50818])
      assert.is_true(env.printed("Invincible: attempts set to 12."))
    end)

    it("accepts part of the name, ignoring case", function()
      env.slash("mounts set invin 3")

      assert.equal(3, IntroVertDB.attempts[50818])
    end)

    it("prefers an exact name over partial matches", function()
      env.mounts[45693] = { mountID = 304, name = "Invincible's Shadow", collected = false }

      env.slash("mounts set invincible 7")

      assert.equal(7, IntroVertDB.attempts[50818])
    end)

    it("asks to be more specific when several mounts match", function()
      env.slash("mounts set i 5")

      assert.is_true(env.printed("Several mounts match 'i': Invincible, Mimiron's Head. Be more specific."))
      assert.is_nil(IntroVertDB.attempts[50818])
    end)

    it("reports a name that matches nothing", function()
      env.slash("mounts set Nothing 5")

      assert.is_true(env.printed("No tracked mount matches 'Nothing'."))
    end)

    it("shows usage for a missing or invalid count", function()
      env.slash("mounts set invincible")
      env.slash("mounts set invincible -2")
      env.slash("mounts set invincible 999999")

      local usages = 0
      for _, line in ipairs(env.prints) do
        if line:find("Usage: /iv mounts set", 1, true) then
          usages = usages + 1
        end
      end
      assert.equal(3, usages)
      assert.is_nil(IntroVertDB.attempts[50818])
    end)
  end)
end)
