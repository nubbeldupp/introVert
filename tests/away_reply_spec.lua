local helper = require("tests.helper")
local Wow = require("tests.support.wow")

describe("Auto-away reply", function()
  local env, ns

  local function setAfk(afk)
    env.afk = afk
    env.fire("PLAYER_FLAGS_CHANGED", "player")
  end

  local function whisper(text, author, flags)
    env.fire("CHAT_MSG_WHISPER", text, author, "", "", "", flags or "", 0, 0, "", 0, 1, "Player-1-X")
  end

  local function bnWhisper(text, author, bnSenderID)
    env.fire("CHAT_MSG_BN_WHISPER", text, author, "", "", "", "", 0, 0, "", 0, 1, "", bnSenderID)
  end

  before_each(function()
    env = Wow.install()
    ns = Wow.loadAddon(helper)
    env.fire("ADDON_LOADED", "IntroVert")
    ns.UpdateSetting({ "shields", "awayReply" }, true)
  end)

  after_each(function()
    Wow.uninstall()
  end)

  describe("replying", function()
    it("whispers back once per sender while you are away", function()
      setAfk(true)

      whisper("hey", "Anna-Realm")
      whisper("you there?", "Anna-Realm")

      assert.equal(1, #env.sent)
      assert.same({ text = "Away for a bit, I'll answer when I'm back!", channel = "WHISPER", target = "Anna-Realm" },
        env.sent[1])
    end)

    it("replies to Battle.net whispers through Battle.net", function()
      setAfk(true)

      bnWhisper("hi", "Friend", 42)

      assert.same({ { id = 42, text = "Away for a bit, I'll answer when I'm back!" } }, env.bnSent)
    end)

    it("stays silent while you are at the keyboard", function()
      whisper("hey", "Anna-Realm")

      assert.equal(0, #env.sent)
    end)

    it("replies again after you were back and away again", function()
      setAfk(true)
      whisper("hey", "Anna-Realm")
      setAfk(false)
      setAfk(true)

      whisper("hey again", "Anna-Realm")

      assert.equal(2, #env.sent)
    end)

    it("sends no reply when switched off but still keeps the summary", function()
      ns.UpdateSetting({ "shields", "awayReply" }, false)
      env.time = 1000
      setAfk(true)
      whisper("hey", "Anna-Realm")
      env.time = 1000 + 600

      setAfk(false)

      assert.equal(0, #env.sent)
      assert.is_true(env.printed("While you were away (10m): 1 whisper from Anna-Realm."))
    end)

    it("ignores Game Masters and recruitment spam", function()
      setAfk(true)

      whisper("Hello from support", "Gm-Realm", "GM")
      whisper("<Nightfall> is recruiting!", "Spammer")
      setAfk(false)

      assert.equal(0, #env.sent)
      assert.is_false(env.printed("While you were away"))
    end)

    it("ignores unreadable (secret) senders", function()
      setAfk(true)
      env.secret = true

      whisper("hey", "Anna-Realm")

      assert.equal(0, #env.sent)
    end)

    it("ignores flag changes of other units", function()
      env.afk = true
      env.fire("PLAYER_FLAGS_CHANGED", "party1")

      whisper("hey", "Anna-Realm")

      assert.equal(0, #env.sent)
    end)

    it("keeps working when the client refuses to send", function()
      env.sendFails = true
      setAfk(true)

      whisper("hey", "Anna-Realm")
      setAfk(false)

      assert.is_true(env.printed("1 whisper from Anna-Realm"))
    end)
  end)

  describe("coming back", function()
    it("lists who whispered while you were away", function()
      env.time = 0
      setAfk(true)
      whisper("hey", "Anna-Realm")
      bnWhisper("hi", "Friend", 42)
      env.time = 20 * 60

      setAfk(false)

      assert.is_true(env.printed("While you were away (20m): 2 whispers from Anna-Realm, Friend."))
    end)

    it("prints nothing when nobody whispered", function()
      setAfk(true)
      setAfk(false)

      assert.is_false(env.printed("While you were away"))
    end)
  end)

  describe("options", function()
    it("adds a switch and a reply editor", function()
      assert.is_not_nil(env.settings.byVariable.IntroVert_shields_awayReply)
      local hasButton = false
      for _, init in ipairs(env.settings.initializers) do
        if init.kind == "button" and init.name == "Away replies" then
          hasButton = true
        end
      end
      assert.is_true(hasButton)
    end)

    it("keeps a reply with a comma as one reply", function()
      for _, init in ipairs(env.settings.initializers) do
        if init.kind == "button" and init.name == "Away replies" then
          init.onClick()
        end
      end
      assert.equal("Away for a bit, I'll answer when I'm back!", env.popup.editBox:GetText())

      env.acceptPopup("Away for a bit, back soon!; brb")

      assert.same({ "Away for a bit, back soon!", "brb" }, IntroVertDB.shields.awayReplies)
    end)

    it("is off by default", function()
      assert.is_false(ns.Defaults.values.shields.awayReply)
    end)
  end)
end)
