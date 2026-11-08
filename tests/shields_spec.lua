local helper = require("tests.helper")
local Wow = require("tests.support.wow")

describe("Do Not Disturb", function()
  local env, ns

  before_each(function()
    env = Wow.install()
    ns = Wow.loadAddon(helper)
    env.fire("ADDON_LOADED", "IntroVert")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  describe("declining", function()
    it("declines guild invites and closes the popup", function()
      env.fire("GUILD_INVITE_REQUEST", "Recruiter-Realm", "<Big Guild>")

      assert.equal(1, env.declines.guild)
      assert.same({ "GUILD_INVITE" }, env.hiddenPopups)
      assert.is_true(env.printed("Declined guild invite from Recruiter-Realm (<Big Guild>)."))
    end)

    it("declines duels and pet battle duels", function()
      env.fire("DUEL_REQUESTED", "Show-Off")
      env.fire("PET_BATTLE_PVP_DUEL_REQUESTED", "Pet-Fan")

      assert.equal(1, env.declines.duel)
      assert.equal(1, env.declines.petDuel)
      assert.same({ "DUEL_REQUESTED", "PET_BATTLE_PVP_DUEL_REQUESTED" }, env.hiddenPopups)
    end)

    it("declines group invites from strangers", function()
      env.fire("PARTY_INVITE_REQUEST", "Stranger", false, false, true, true, false, "Player-1-STRANGER")

      assert.equal(1, env.declines.group)
      assert.is_true(env.printed("Declined group invite from Stranger."))
    end)

    it("lets group invites from friends and Battle.net friends through", function()
      env.friends = { ["Player-1-FRIEND"] = true }
      env.bnetFriends = { ["Player-1-BNET"] = true }

      env.fire("PARTY_INVITE_REQUEST", "Friend", false, false, true, true, false, "Player-1-FRIEND")
      env.fire("PARTY_INVITE_REQUEST", "Buddy", false, false, true, true, false, "Player-1-BNET")

      assert.is_nil(env.declines.group)
    end)

    it("respects each switch", function()
      for _, key in ipairs({ "guildInvites", "duels", "petDuels", "groupInvites" }) do
        ns.UpdateSetting({ "shields", key }, false)
      end

      env.fire("GUILD_INVITE_REQUEST", "Recruiter", "<G>")
      env.fire("DUEL_REQUESTED", "Show-Off")
      env.fire("PET_BATTLE_PVP_DUEL_REQUESTED", "Pet-Fan")
      env.fire("PARTY_INVITE_REQUEST", "Stranger", false, false, true, true, false, "Player-1-X")

      assert.same({}, env.declines)
    end)

    it("sends no reply by default", function()
      env.fire("GUILD_INVITE_REQUEST", "Recruiter", "<G>")

      assert.equal(0, #env.sent)
    end)

    it("whispers a polite reply when enabled", function()
      ns.UpdateSetting({ "shields", "reply" }, true)

      env.fire("GUILD_INVITE_REQUEST", "Recruiter-Realm", "<G>")

      assert.same({ text = "Thanks, but I play solo!", channel = "WHISPER", target = "Recruiter-Realm" }, env.sent[1])
    end)
  end)

  describe("recruitment spam filter", function()
    it("hides recruitment in public channels and whispers", function()
      assert.is_true(env.chat("CHAT_MSG_CHANNEL", "<Nightfall> is recruiting!", "Spammer", 1))
      assert.is_true(env.chat("CHAT_MSG_WHISPER", "Gilde sucht Mitglieder", "Werber", 2))
    end)

    it("shows normal messages", function()
      assert.is_false(env.chat("CHAT_MSG_CHANNEL", "WTS flasks", "Trader", 1))
    end)

    it("counts a line once across chat windows", function()
      env.chat("CHAT_MSG_CHANNEL", "Guild recruiting", "Spammer", 7, 3)

      env.slash("dnd")

      assert.is_true(env.printed("hid 1 recruitment messages"))
    end)

    it("can be switched off", function()
      ns.UpdateSetting({ "shields", "spam" }, false)

      assert.is_false(env.chat("CHAT_MSG_CHANNEL", "<Nightfall> is recruiting!", "Spammer", 1))
    end)

    it("shows unreadable (secret) lines", function()
      env.secret = true

      assert.is_false(env.chat("CHAT_MSG_CHANNEL", "recruiting", "Spammer", 1))
    end)
  end)

  describe("/iv dnd", function()
    it("shows what was declined and hidden this session", function()
      env.fire("GUILD_INVITE_REQUEST", "Recruiter", "<G>")
      env.fire("DUEL_REQUESTED", "Show-Off")

      env.slash("dnd")

      assert.is_true(env.printed(
        "This session: declined 1 guild invites, 1 duels, 0 pet battle duels, 0 group invites; hid 0 recruitment messages."))
    end)

    it("prints the log", function()
      env.fire("GUILD_INVITE_REQUEST", "Recruiter", "<G>")
      env.chat("CHAT_MSG_CHANNEL", "Guild recruiting", "Spammer", 1)

      env.slash("dnd log")

      assert.is_true(env.printed("Declined guild invite from Recruiter (<G>)."))
      assert.is_true(env.printed("Hid Spammer: Guild recruiting"))
    end)

    it("says when the log is empty", function()
      env.slash("dnd log")

      assert.is_true(env.printed("Nothing declined or hidden this session."))
    end)

    it("turns everything off and on", function()
      env.slash("dnd off")
      assert.is_false(IntroVertDB.shields.guildInvites)
      assert.is_false(IntroVertDB.shields.spam)

      env.slash("dnd on")
      assert.is_true(IntroVertDB.shields.duels)
    end)

    it("is listed in /iv help", function()
      env.slash("help")

      assert.is_true(env.printed("/iv dnd"))
    end)
  end)

  describe("options", function()
    it("adds a switch for each shield and a reply editor", function()
      for _, key in ipairs({ "guildInvites", "duels", "petDuels", "groupInvites", "spam", "reply" }) do
        assert.is_not_nil(env.settings.byVariable["IntroVert_shields_" .. key], key)
      end
      local hasRepliesButton = false
      for _, init in ipairs(env.settings.initializers) do
        if init.kind == "button" and init.name == "Polite replies" then
          hasRepliesButton = true
        end
      end
      assert.is_true(hasRepliesButton)
    end)
  end)
end)
