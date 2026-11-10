local helper = require("tests.helper")

local DAY = 24 * 3600
local NOW = 1000000

local DATA = {
  raids = {
    {
      instanceID = 631, name = "Icecrown Citadel",
      mounts = { { itemID = 50818, boss = "The Lich King", difficulties = { 6 }, note = "25 Heroic" } },
    },
    {
      instanceID = 603, name = "Ulduar",
      mounts = { { itemID = 45693, boss = "Yogg-Saron", note = "no Keepers" } },
    },
    {
      instanceID = 550, name = "Tempest Keep",
      mounts = { { itemID = 32458, boss = "Kael'thas Sunstrider" } },
    },
  },
}

local MOUNTS = {
  [50818] = { name = "Invincible", collected = false },
  [45693] = { name = "Mimiron's Head", collected = true },
}

local function lookup(itemID)
  return MOUNTS[itemID]
end

describe("Raid mounts", function()
  local Mounts

  before_each(function()
    Mounts = helper.loadPure({ "Modules/Raids/Lockouts.lua", "Modules/Raids/Mounts.lua" }).RaidMounts
  end)

  describe("resolve", function()
    it("lists missing mounts per raid with their in-game names", function()
      local result = Mounts.resolve(DATA, lookup)

      assert.equal(1, #result.raids)
      assert.equal("Icecrown Citadel", result.raids[1].name)
      assert.same({
        { itemID = 50818, mountName = "Invincible", boss = "The Lich King", note = "25 Heroic" },
      }, result.raids[1].missing)
    end)

    it("leaves out raids whose mounts are all collected", function()
      local result = Mounts.resolve(DATA, lookup)

      for _, raid in ipairs(result.raids) do
        assert.are_not.equal("Ulduar", raid.name)
      end
    end)

    it("reports items the game does not recognise as mounts", function()
      local result = Mounts.resolve(DATA, lookup)

      assert.same({ { itemID = 32458, raid = "Tempest Keep", boss = "Kael'thas Sunstrider" } }, result.unresolved)
    end)

    it("counts items that are still loading separately from unknown ones", function()
      local pendingLookup = function(itemID)
        if itemID == 32458 then
          return { pending = true }
        end
        return MOUNTS[itemID]
      end

      local result = Mounts.resolve(DATA, pendingLookup)

      assert.equal(1, result.pending)
      assert.same({}, result.unresolved)
    end)

    it("counts collected mounts", function()
      local result = Mounts.resolve(DATA, lookup)

      assert.equal(1, result.collected)
      assert.equal(2, result.known)
    end)
  end)

  describe("attemptItems", function()
    it("matches the boss case-insensitively on an allowed difficulty", function()
      assert.same({ 50818 }, Mounts.attemptItems(DATA, 631, 6, "the lich king"))
    end)

    it("ignores the wrong difficulty", function()
      assert.same({}, Mounts.attemptItems(DATA, 631, 4, "The Lich King"))
    end)

    it("accepts any difficulty when none is listed", function()
      assert.same({ 45693 }, Mounts.attemptItems(DATA, 603, 3, "Yogg-Saron"))
    end)

    it("ignores other bosses and other raids", function()
      assert.same({}, Mounts.attemptItems(DATA, 631, 6, "Sindragosa"))
      assert.same({}, Mounts.attemptItems(DATA, 999, 6, "The Lich King"))
    end)
  end)

  describe("characterStatus", function()
    local characters = {
      ["Abe-Realm"] = { lockouts = { { instanceID = 631, expiresAt = NOW + DAY } } },
      ["Bob-Realm"] = { lockouts = { { instanceID = 631, expiresAt = NOW - 1 } } },
      ["Cid-Realm"] = { lockouts = { { instanceID = 603, expiresAt = NOW + DAY } } },
    }

    it("lists every character with its active lockout for that raid", function()
      assert.same({
        { name = "Abe-Realm", expiresAt = NOW + DAY },
        { name = "Bob-Realm" },
        { name = "Cid-Realm" },
      }, Mounts.characterStatus(characters, 631, NOW))
    end)
  end)

  describe("shortName", function()
    it("drops the realm of the current realm", function()
      assert.equal("Abe", Mounts.shortName("Abe-Dun Morogh", "Dun Morogh"))
    end)

    it("keeps the realm of other realms", function()
      assert.equal("Abe-Other", Mounts.shortName("Abe-Other", "Dun Morogh"))
    end)
  end)

  describe("lines", function()
    local function link(key, text)
      return "<" .. key .. ">" .. text
    end

    local COLORS = { ["Abe-Realm"] = "ff8788ee" }

    local function options(openKey)
      return {
        realm = "Realm", link = link,
        isExpanded = function(key) return key == openKey end,
        colorOf = function(key) return COLORS[key] end,
      }
    end

    local function locked(instanceID)
      return { lockouts = { { instanceID = instanceID, expiresAt = NOW + DAY } } }
    end

    local free = { lockouts = {} }

    it("shows a collapsed, clickable row per missing mount with a status summary", function()
      local resolved = Mounts.resolve(DATA, lookup)
      local characters = { ["Abe-Realm"] = free, ["Bob-Realm"] = free }

      local lines = Mounts.lines(resolved, { [50818] = 12 }, characters, NOW, options())

      assert.same({
        "Click a mount to show or hide your characters.",
        "",
        "<50818>[+] Invincible - The Lich King (25 Heroic), 12 attempts",
        "  Icecrown Citadel: free on all 2 characters",
        "",
        "Collected 1 of 2 tracked raid mounts.",
      }, lines)
    end)

    it("counts free characters without naming the locked ones", function()
      local characters = { ["Abe-Realm"] = locked(631), ["Bob-Realm"] = free, ["Cid-Other"] = locked(631) }

      local lines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, characters, NOW, options())

      assert.equal("  Icecrown Citadel: free on 1 of 3 characters", lines[4])
    end)

    it("counts zero when every character is locked", function()
      local characters = { ["Abe-Realm"] = locked(631), ["Bob-Realm"] = locked(631) }

      local lines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, characters, NOW, options())

      assert.equal("  Icecrown Citadel: free on 0 of 2 characters", lines[4])
    end)

    it("keeps the summary short for a single character", function()
      local freeLines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, { ["Abe-Realm"] = free }, NOW, options())
      local lockedLines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, { ["Abe-Realm"] = locked(631) }, NOW, options())

      assert.equal("  Icecrown Citadel: free", freeLines[4])
      assert.equal("  Icecrown Citadel: locked until reset", lockedLines[4])
    end)

    it("says when no character is recorded yet", function()
      local lines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, {}, NOW, options())

      assert.equal("  Icecrown Citadel: no characters recorded yet", lines[4])
    end)

    it("lists each character in class colour with its reset time when the mount is opened", function()
      local characters = { ["Abe-Realm"] = locked(631), ["Bob-Realm"] = free }

      local lines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, characters, NOW, options("50818"))

      assert.same({
        "<50818>[-] Invincible - The Lich King (25 Heroic), 0 attempts",
        "  Icecrown Citadel: free on 1 of 2 characters",
        "    |cff8788eeAbe|r - locked, resets in 1d 0h",
        "    Bob - free",
      }, { lines[3], lines[4], lines[5], lines[6] })
    end)

    it("adds a loading hint when items are still loading", function()
      local resolved = { raids = {}, unresolved = {}, collected = 0, known = 0, pending = 3 }

      local lines = Mounts.lines(resolved, {}, {}, NOW, options())

      assert.equal("Still loading 3 mounts from the game, try again in a few seconds.", lines[#lines])
      assert.equal("Collected 0 of 0 tracked raid mounts.", lines[1])
    end)

    it("uses singular for one attempt and skips an empty note", function()
      local data = { raids = { { instanceID = 1, name = "Raid", mounts = { { itemID = 50818, boss = "Boss" } } } } }

      local lines = Mounts.lines(Mounts.resolve(data, lookup), { [50818] = 1 }, {}, NOW, options())

      assert.equal("<50818>[+] Invincible - Boss, 1 attempt", lines[3])
    end)

    it("works without options: plain titles, everything collapsed", function()
      local lines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, {}, NOW)

      assert.equal("[+] Invincible - The Lich King (25 Heroic), 0 attempts", lines[3])
    end)
  end)
end)

describe("Raid mount data", function()
  local data

  before_each(function()
    data = helper.loadPure({ "Modules/Raids/MountData.lua" }).RaidMountData
  end)

  it("has a well-formed entry for every raid and mount", function()
    assert.is_true(#data.raids > 0)
    for _, raid in ipairs(data.raids) do
      assert.equal("number", type(raid.instanceID), raid.name)
      assert.equal("string", type(raid.name))
      assert.equal("number", type(raid.minutes), raid.name)
      assert.is_true(#raid.mounts > 0, raid.name)
      for _, mount in ipairs(raid.mounts) do
        assert.equal("number", type(mount.itemID), raid.name)
        assert.equal("string", type(mount.boss), raid.name)
      end
    end
  end)

  it("lists each item only once", function()
    local seen = {}
    for _, raid in ipairs(data.raids) do
      for _, mount in ipairs(raid.mounts) do
        assert.is_nil(seen[mount.itemID], "duplicate item " .. mount.itemID)
        seen[mount.itemID] = true
      end
    end
  end)
end)
