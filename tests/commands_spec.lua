local helper = require("tests.helper")

describe("Quiet Commands.parse", function()
  local Commands

  before_each(function()
    local ns = helper.loadPure({
      "Modules/Quiet/Profile.lua",
      "Modules/Quiet/Filter.lua",
      "Modules/Quiet/Commands.lua",
    })
    Commands = ns.QuietCommands
  end)

  it("defaults to status", function()
    assert.same({ action = "status" }, Commands.parse(""))
    assert.same({ action = "status" }, Commands.parse("  status "))
  end)

  it("parses on/off for all profiles", function()
    assert.same({ action = "enable", value = true }, Commands.parse("on"))
    assert.same({ action = "enable", value = false }, Commands.parse("OFF"))
  end)

  it("parses a per-profile chat level", function()
    assert.same(
      { action = "level", profile = "lfr", value = "all" },
      Commands.parse("lfr all")
    )
  end)

  it("rejects an unknown chat level", function()
    local result = Commands.parse("dungeon shouty")

    assert.equal("error", result.action)
    assert.matches("shouty", result.message)
  end)

  it("parses the log command", function()
    assert.same({ action = "log" }, Commands.parse("log"))
  end)

  it("returns help for anything else", function()
    assert.same({ action = "help" }, Commands.parse("dance"))
  end)
end)
