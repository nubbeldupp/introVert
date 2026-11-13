local helper = require("tests.helper")

describe("Finder", function()
  local Finder

  before_each(function()
    Finder = helper.loadPure({
      "Modules/Achievements/Achievements.lua",
      "Modules/Finder/Finder.lua",
    }).Finder
  end)

  local function suggestion(title, minutes, value)
    return { title = title, minutes = minutes, value = value }
  end

  describe("mountSuggestions", function()
    local raids = {
      { instanceID = 631, name = "Icecrown Citadel", minutes = 20,
        missing = { { mountName = "Invincible" } } },
      { instanceID = 532, name = "Karazhan", minutes = 15,
        missing = { { mountName = "Fiery Warhorse" }, { mountName = "Midnight" } } },
      { instanceID = 603, name = "Ulduar", missing = { { mountName = "Mimiron's Head" } } },
    }

    it("suggests raids this character is not locked to, valued by missing mounts", function()
      local result = Finder.mountSuggestions(raids, { [631] = true })

      assert.same({
        { id = "raid:532", raid = 532, title = "Karazhan: Fiery Warhorse, Midnight", minutes = 15,
          value = 2 * Finder.MOUNT_VALUE },
        { id = "raid:603", raid = 603, title = "Ulduar: Mimiron's Head", minutes = Finder.DEFAULT_RAID_MINUTES,
          value = Finder.MOUNT_VALUE },
      }, result)
    end)

    it("adds each mount's condition note", function()
      local result = Finder.mountSuggestions({
        { instanceID = 1205, name = "Blackrock Foundry", minutes = 15,
          missing = { { mountName = "Ironhoof Destroyer", note = "Mythic" } } },
      }, {})

      assert.equal("Blackrock Foundry: Ironhoof Destroyer (Mythic)", result[1].title)
    end)
  end)

  describe("vaultOpen", function()
    it("is true while a world vault slot is unfinished", function()
      assert.is_true(Finder.vaultOpen({ { progress = 2, threshold = 2 }, { progress = 2, threshold = 4 } }))
      assert.is_false(Finder.vaultOpen({ { progress = 2, threshold = 2 } }))
      assert.is_false(Finder.vaultOpen({}))
    end)
  end)

  describe("delveSuggestions", function()
    it("values bountiful delves higher while the vault is open", function()
      local open = Finder.delveSuggestions({ { name = "Fungal Folly", zone = "Isle of Dorn" } }, true)
      local closed = Finder.delveSuggestions({ { name = "Fungal Folly", zone = "Isle of Dorn" } }, false)

      assert.same({
        id = "delve:Fungal Folly", delve = "Fungal Folly",
        title = "Bountiful delve: Fungal Folly (Isle of Dorn) (vault)",
        minutes = Finder.DELVE_MINUTES, value = Finder.VAULT_DELVE_VALUE,
      }, open[1])
      assert.equal("Bountiful delve: Fungal Folly (Isle of Dorn)", closed[1].title)
      assert.equal(Finder.DELVE_VALUE, closed[1].value)
    end)
  end)

  describe("plan", function()
    it("picks the best value per minute first and stops at the budget", function()
      local result = Finder.plan({
        suggestion("Slow", 40, 4),
        suggestion("Fast", 10, 3),
        suggestion("Medium", 20, 4),
      }, 35)

      assert.same({ "Fast", "Medium" }, { result.picked[1].title, result.picked[2].title })
      assert.equal(30, result.used)
      assert.equal("Slow", result.rest[1].title)
    end)

    it("still fits smaller items after a big one does not fit", function()
      local result = Finder.plan({ suggestion("Big", 50, 10), suggestion("Small", 10, 1) }, 30)

      assert.equal("Small", result.picked[1].title)
    end)

    it("does not change the input", function()
      local input = { suggestion("B", 10, 1), suggestion("A", 10, 5) }

      Finder.plan(input, 60)

      assert.equal("B", input[1].title)
    end)
  end)

  describe("checklist", function()
    local NOW = 1000
    local raidItem = { id = "raid:631", raid = 631, title = "Icecrown Citadel: Invincible", minutes = 20, value = 3 }
    local delveItem = { id = "delve:Fungal Folly", delve = "Fungal Folly", title = "Bountiful delve: Fungal Folly",
      minutes = 15, value = 5 }

    it("freezes the picked suggestions with the budget and creation time", function()
      local plan = Finder.plan({ raidItem, delveItem, suggestion("Long", 90, 1) }, 40)

      local checklist = Finder.newChecklist(plan, 40, NOW)

      assert.same({
        createdAt = NOW, budget = 40, used = 35,
        items = {
          { id = "delve:Fungal Folly", delve = "Fungal Folly", title = "Bountiful delve: Fungal Folly", minutes = 15 },
          { id = "raid:631", raid = 631, title = "Icecrown Citadel: Invincible", minutes = 20 },
        },
      }, checklist)
    end)

    it("counts a raid as done once this character is locked to it", function()
      assert.is_true(Finder.isDone(raidItem, { locked = { [631] = true }, delves = {}, since = NOW }))
      assert.is_false(Finder.isDone(raidItem, { locked = {}, delves = {}, since = NOW }))
    end)

    it("counts a delve as done once it was finished after the checklist was made", function()
      local after = { delves = { ["Fungal Folly"] = { lastAt = NOW + 1 } }, locked = {}, since = NOW }
      local before = { delves = { ["Fungal Folly"] = { lastAt = NOW - 1 } }, locked = {}, since = NOW }

      assert.is_true(Finder.isDone(delveItem, after))
      assert.is_false(Finder.isDone(delveItem, before))
      assert.is_false(Finder.isDone(delveItem, { delves = {}, locked = {}, since = NOW }))
    end)

    it("leaves checklist items out of the other suggestions", function()
      local checklist = Finder.newChecklist(Finder.plan({ raidItem }, 30), 30, NOW)
      local plan = Finder.plan({ raidItem, delveItem }, 60)

      assert.same({ delveItem }, Finder.otherSuggestions(plan, checklist))
    end)
  end)

  describe("lines", function()
    local NOW = 1000
    local fast = { id = "a", title = "Fast", minutes = 10, value = 3 }
    local slow = { id = "b", title = "Slow", minutes = 50, value = 1 }

    local function state(doneIds)
      return { isDone = function(item) return (doneIds or {})[item.id] == true end }
    end

    it("shows the checklist, other suggestions and almost-finished achievements", function()
      local checklist = Finder.newChecklist(Finder.plan({ fast, slow }, 30), 30, NOW)
      local achievements = {
        { name = "Anvil Mastery II", done = 491, total = 500, fraction = 0.982 },
        { name = "Far", done = 1, total = 10, fraction = 0.1 },
        { name = "Mount Thing", done = 9, total = 10, fraction = 0.9, reward = "Mount: X" },
      }

      assert.same({
        "Checklist for 30 min: 0 of 1 done (about 10 min planned)",
        "  [ ] 10 min  Fast",
        "Also worth doing",
        "  50 min  Slow",
        "Almost finished achievements",
        "  98% Anvil Mastery II (491/500)",
        "  90% Mount Thing (9/10) - Mount: X",
        "",
        "  /iv finder new starts a fresh checklist.",
      }, Finder.lines(checklist, state(), { slow }, achievements))
    end)

    it("ticks done items and greys them out", function()
      local checklist = Finder.newChecklist(Finder.plan({ fast, slow }, 60), 60, NOW)

      local lines = Finder.lines(checklist, state({ a = true }), {}, {})

      assert.equal("Checklist for 60 min: 1 of 2 done (about 60 min planned)", lines[1])
      assert.equal("  |cff808080[x] 10 min  Fast|r", lines[2])
      assert.equal("  [ ] 50 min  Slow", lines[3])
    end)

    it("cheers when everything is done", function()
      local checklist = Finder.newChecklist(Finder.plan({ fast }, 30), 30, NOW)

      local lines = Finder.lines(checklist, state({ a = true }), {}, {})

      assert.equal("  All done. Nice session!", lines[3])
    end)

    it("explains when nothing fits the budget", function()
      local checklist = Finder.newChecklist(Finder.plan({ slow }, 30), 30, NOW)

      local lines = Finder.lines(checklist, state(), { slow }, {})

      assert.equal("  Nothing fits in 30 min. Try a longer session.", lines[2])
    end)

    it("explains when there is nothing to suggest", function()
      local checklist = Finder.newChecklist(Finder.plan({}, 30), 30, NOW)

      local lines = Finder.lines(checklist, state(), {}, {})

      assert.same({ "Checklist for 30 min: 0 of 0 done (about 0 min planned)", "  No suggestions right now." },
        { lines[1], lines[2] })
    end)
  end)
end)
