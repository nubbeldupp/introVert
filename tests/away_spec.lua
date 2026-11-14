local helper = require("tests.helper")
local Wow = require("tests.support.wow")

describe("Away (pure)", function()
  local Away

  before_each(function()
    Wow.install()
    local ns = Wow.loadAddon(helper)
    Away = ns.Away
  end)

  after_each(function()
    Wow.uninstall()
  end)

  it("starts an empty away period", function()
    assert.same({ since = 100, count = 0, senders = {}, replied = {} }, Away.start(100))
  end)

  it("counts whispers and lists each sender once, in order", function()
    local state = Away.start(0)
    state = Away.addWhisper(state, "Anna")
    state = Away.addWhisper(state, "Bob")
    state = Away.addWhisper(state, "Anna")

    assert.equal(3, state.count)
    assert.same({ "Anna", "Bob" }, state.senders)
  end)

  it("does not change the state it was given", function()
    local state = Away.start(0)

    Away.addWhisper(state, "Anna")
    Away.markReplied(state, "Anna")

    assert.same(Away.start(0), state)
  end)

  it("replies to each sender once", function()
    local state = Away.start(0)
    assert.is_true(Away.needsReply(state, "Anna"))

    state = Away.markReplied(state, "Anna")

    assert.is_false(Away.needsReply(state, "Anna"))
    assert.is_true(Away.needsReply(state, "Bob"))
  end)

  it("sums up the away period", function()
    local state = Away.addWhisper(Away.addWhisper(Away.start(0), "Anna"), "Bob")

    assert.equal("While you were away (12m): 2 whispers from Anna, Bob.", Away.summary(state, 12 * 60))
  end)

  it("uses the singular for one whisper", function()
    local state = Away.addWhisper(Away.start(0), "Anna")

    assert.equal("While you were away (5m): 1 whisper from Anna.", Away.summary(state, 5 * 60))
  end)

  it("has no summary when nobody whispered", function()
    assert.is_nil(Away.summary(Away.start(0), 600))
  end)
end)
