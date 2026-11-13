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
  [13335] = { name = "Deathcharger", collected = false },
  [32768] = { name = "Raven Lord", collected = true },
}

local DUNGEON_DATA = {
  raids = {},
  dungeons = {
    {
      instanceID = 329, name = "Stratholme",
      mounts = { { itemID = 13335, boss = "Lord Aurius Rivendare" } },
    },
    {
      instanceID = 556, name = "Sethekk Halls",
      mounts = { { itemID = 32768, boss = "Anzu", difficulties = { 2 }, note = "Heroic" } },
    },
  },
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

    it("lists missing dungeon mounts separately from raids and counts them in the totals", function()
      local result = Mounts.resolve(DUNGEON_DATA, lookup)

      assert.same({}, result.raids)
      assert.equal(1, #result.dungeons)
      assert.equal("Stratholme", result.dungeons[1].name)
      assert.equal(1, result.collected)
      assert.equal(2, result.known)
    end)

    it("works with data that has no dungeons", function()
      assert.same({}, Mounts.resolve(DATA, lookup).dungeons)
    end)
  end)

  describe("match", function()
    it("finds dungeon mounts by name too", function()
      assert.same({ { itemID = 13335, name = "Deathcharger" } }, Mounts.match(DUNGEON_DATA, lookup, "death"))
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

    it("counts dungeon bosses, respecting the heroic-only drops", function()
      assert.same({ 13335 }, Mounts.attemptItems(DUNGEON_DATA, 329, 1, "Lord Aurius Rivendare"))
      assert.same({ 32768 }, Mounts.attemptItems(DUNGEON_DATA, 556, 2, "Anzu"))
      assert.same({}, Mounts.attemptItems(DUNGEON_DATA, 556, 1, "Anzu"))
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
        "Raid mounts",
        "<50818>[+] Invincible - The Lich King (25 Heroic), 12 attempts",
        "  Icecrown Citadel: free on all 2 characters",
        "",
        "Collected 1 of 2 tracked mounts.",
      }, lines)
    end)

    it("lists dungeon mounts in their own section, plain, with no lockout to track", function()
      local resolved = Mounts.resolve(DUNGEON_DATA, lookup)

      local lines = Mounts.lines(resolved, { [13335] = 3 }, { ["Abe-Realm"] = free }, NOW, options())

      assert.same({
        "",
        "Dungeon mounts",
        "Deathcharger - Lord Aurius Rivendare, 3 attempts",
        "  Stratholme: no lockout, farm any time",
        "",
        "Collected 1 of 2 tracked mounts.",
      }, lines)
    end)

    it("separates mounts within a section with an empty line", function()
      local data = { raids = DATA.raids, dungeons = DUNGEON_DATA.dungeons }
      local both = function(itemID) return itemID == 32768 and { name = "Raven Lord", collected = false } or lookup(itemID) end

      local lines = Mounts.lines(Mounts.resolve(data, both), {}, {}, NOW, options())

      assert.same({
        "Dungeon mounts",
        "Deathcharger - Lord Aurius Rivendare, 0 attempts",
        "  Stratholme: no lockout, farm any time",
        "",
        "Raven Lord - Anzu (Heroic), 0 attempts",
        "  Sethekk Halls: no lockout, farm any time",
      }, { lines[7], lines[8], lines[9], lines[10], lines[11], lines[12] })
    end)

    it("counts free characters without naming the locked ones", function()
      local characters = { ["Abe-Realm"] = locked(631), ["Bob-Realm"] = free, ["Cid-Other"] = locked(631) }

      local lines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, characters, NOW, options())

      assert.equal("  Icecrown Citadel: free on 1 of 3 characters", lines[5])
    end)

    it("counts zero when every character is locked", function()
      local characters = { ["Abe-Realm"] = locked(631), ["Bob-Realm"] = locked(631) }

      local lines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, characters, NOW, options())

      assert.equal("  Icecrown Citadel: free on 0 of 2 characters", lines[5])
    end)

    it("keeps the summary short for a single character", function()
      local freeLines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, { ["Abe-Realm"] = free }, NOW, options())
      local lockedLines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, { ["Abe-Realm"] = locked(631) }, NOW, options())

      assert.equal("  Icecrown Citadel: free", freeLines[5])
      assert.equal("  Icecrown Citadel: locked until reset", lockedLines[5])
    end)

    it("says when no character is recorded yet", function()
      local lines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, {}, NOW, options())

      assert.equal("  Icecrown Citadel: no characters recorded yet", lines[5])
    end)

    it("lists each character in class colour with its reset time when the mount is opened", function()
      local characters = { ["Abe-Realm"] = locked(631), ["Bob-Realm"] = free }

      local lines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, characters, NOW, options("50818"))

      assert.same({
        "<50818>[-] Invincible - The Lich King (25 Heroic), 0 attempts",
        "  Icecrown Citadel: free on 1 of 2 characters",
        "    |cff8788eeAbe|r - locked, resets in 1d 0h",
        "    Bob - free",
      }, { lines[4], lines[5], lines[6], lines[7] })
    end)

    it("adds a loading hint when items are still loading", function()
      local resolved = { raids = {}, unresolved = {}, collected = 0, known = 0, pending = 3 }

      local lines = Mounts.lines(resolved, {}, {}, NOW, options())

      assert.equal("Still loading 3 mounts from the game, try again in a few seconds.", lines[#lines])
      assert.equal("Collected 0 of 0 tracked mounts.", lines[1])
    end)

    it("uses singular for one attempt and skips an empty note", function()
      local data = { raids = { { instanceID = 1, name = "Raid", mounts = { { itemID = 50818, boss = "Boss" } } } } }

      local lines = Mounts.lines(Mounts.resolve(data, lookup), { [50818] = 1 }, {}, NOW, options())

      assert.equal("<50818>[+] Invincible - Boss, 1 attempt", lines[4])
    end)

    it("works without options: plain titles, everything collapsed", function()
      local lines = Mounts.lines(Mounts.resolve(DATA, lookup), {}, {}, NOW)

      assert.equal("[+] Invincible - The Lich King (25 Heroic), 0 attempts", lines[4])
    end)
  end)
end)

describe("Raid mount data", function()
  local data

  before_each(function()
    data = helper.loadPure({ "Modules/Raids/MountData.lua" }).RaidMountData
  end)

  local function allInstances()
    local list = {}
    for _, group in ipairs({ data.raids, data.dungeons }) do
      for _, instance in ipairs(group) do
        list[#list + 1] = instance
      end
    end
    return list
  end

  it("has raids and dungeons", function()
    assert.is_true(#data.raids > 0)
    assert.is_true(#data.dungeons > 0)
  end)

  it("has a well-formed entry for every instance and mount", function()
    for _, instance in ipairs(allInstances()) do
      assert.equal("number", type(instance.instanceID), instance.name)
      assert.equal("string", type(instance.name))
      assert.equal("number", type(instance.minutes), instance.name)
      assert.is_true(#instance.mounts > 0, instance.name)
      for _, mount in ipairs(instance.mounts) do
        assert.equal("number", type(mount.itemID), instance.name)
        assert.equal("string", type(mount.boss), instance.name)
      end
    end
  end)

  it("lists each item and instance only once", function()
    local seenItems, seenInstances = {}, {}
    for _, instance in ipairs(allInstances()) do
      assert.is_nil(seenInstances[instance.instanceID], "duplicate instance " .. instance.instanceID)
      seenInstances[instance.instanceID] = true
      for _, mount in ipairs(instance.mounts) do
        assert.is_nil(seenItems[mount.itemID], "duplicate item " .. mount.itemID)
        seenItems[mount.itemID] = true
      end
    end
  end)
end)
