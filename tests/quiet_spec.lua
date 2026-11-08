local helper = require("tests.helper")
local Wow = require("tests.support.wow")

local PARTY = "CHAT_MSG_INSTANCE_CHAT"
local PARTY_LEADER = "CHAT_MSG_INSTANCE_CHAT_LEADER"
local STRANGER = "Stranger-OtherRealm"

describe("Quiet Groups", function()
  local env, ns, nextLine

  local function enterDungeon()
    env.isLFG = true
    env.instance = { inInstance = true, instanceType = "party", difficultyID = 2 }
    env.fire("PLAYER_ENTERING_WORLD")
  end

  local function enterLfr()
    env.isLFG = true
    env.instance = { inInstance = true, instanceType = "raid", difficultyID = 17 }
    env.fire("PLAYER_ENTERING_WORLD")
  end

  local function leaveInstance()
    env.instance = { inInstance = false, instanceType = "none", difficultyID = 0 }
    env.fire("PLAYER_ENTERING_WORLD")
  end

  local function say(text, event, author)
    nextLine = nextLine + 1
    return env.chat(event or PARTY, text, author or STRANGER, nextLine)
  end

  before_each(function()
    nextLine = 0
    env = Wow.install()
    ns = Wow.loadAddon(helper)
    env.fire("ADDON_LOADED", "IntroVert")
  end)

  after_each(function()
    Wow.uninstall()
  end)

  describe("activation", function()
    it("stays off in the open world", function()
      env.fire("PLAYER_ENTERING_WORLD")

      assert.is_false(say("go go go"))
    end)

    it("turns on in a matchmade dungeon and announces it", function()
      enterDungeon()

      assert.matches("Quiet mode on %(dungeon", env.lastPrint())
      assert.is_true(say("go go go"))
    end)

    it("stays off in premade groups", function()
      env.instance = { inInstance = true, instanceType = "party", difficultyID = 2 }
      env.fire("PLAYER_ENTERING_WORLD")

      assert.is_false(say("go go go"))
    end)

    it("stays off when the profile is disabled", function()
      env.slash("quiet off")

      enterDungeon()

      assert.is_false(say("go go go"))
    end)

    it("turns off after leaving the instance", function()
      enterDungeon()

      leaveInstance()

      assert.is_false(say("go go go"))
    end)
  end)

  describe("greeting", function()
    it("greets once in instance chat after a short delay", function()
      enterDungeon()
      assert.equal(0, #env.sent)

      env.runTimers()

      assert.equal(1, #env.sent)
      assert.equal("INSTANCE_CHAT", env.sent[1].channel)
    end)

    it("does not greet again when re-entering with the same group", function()
      enterDungeon()
      env.runTimers()

      leaveInstance()
      enterDungeon()
      env.runTimers()

      assert.equal(1, #env.sent)
    end)

    it("greets again in a new group", function()
      enterDungeon()
      env.runTimers()
      env.isLFG = false
      leaveInstance()

      enterDungeon()
      env.runTimers()

      assert.equal(2, #env.sent)
    end)

    it("skips the greeting when the group is gone before the delay ends", function()
      enterDungeon()
      leaveInstance()

      env.runTimers()

      assert.equal(0, #env.sent)
    end)

    it("respects the greet setting", function()
      ns.UpdateSetting({ "quiet", "greet" }, false)

      enterDungeon()
      env.runTimers()

      assert.equal(0, #env.sent)
    end)
  end)

  describe("chat filter", function()
    it("shows keyword matches and your own lines at the keywords level", function()
      enterDungeon()

      assert.is_false(say("wait for mana"))
      assert.is_false(say("go go", PARTY, "Nubbel-MyRealm"))
      assert.is_true(say("pump it"))
    end)

    it("shows lines that mention your role", function()
      env.role = "HEALER"
      enterDungeon()

      assert.is_false(say("heal pls"))
    end)

    it("picks up a role assigned after the group activated", function()
      env.role = "NONE"
      enterDungeon()
      env.role = "TANK"

      assert.is_false(say("tank pull pls"))
    end)

    it("counts a line once even when several chat windows show it", function()
      enterDungeon()

      env.chat(PARTY, "spam", STRANGER, 99, 3)
      env.slash("quiet")

      assert.matches("1 hidden", env.lastPrint())
    end)

    it("uses the leader level from settings", function()
      env.slash("quiet dungeon leader")
      enterDungeon()

      assert.is_false(say("pull now", PARTY_LEADER))
      assert.is_true(say("pull now"))
    end)

    it("uses the LFR level inside Raid Finder", function()
      env.slash("quiet lfr all")
      enterLfr()

      assert.matches("lfr", env.lastPrint())
      assert.is_true(say("wait"))
    end)

    it("shows unreadable (secret) lines at the keywords level", function()
      enterDungeon()
      env.secret = true

      assert.is_false(say("anything"))
    end)

    it("logs hidden lines with a placeholder when they are secret", function()
      env.slash("quiet dungeon all")
      enterDungeon()
      env.secret = true
      say("anything")
      env.secret = false

      env.slash("quiet log")

      assert.matches("unreadable", env.lastPrint())
    end)
  end)

  describe("encounters", function()
    it("mutes everything during a boss fight", function()
      enterDungeon()

      env.fire("ENCOUNTER_START", 1, "Boss", 2, 5)

      assert.is_true(say("wait"))
    end)

    it("skips boss and wipe muting when encounter focus is off", function()
      ns.UpdateSetting({ "quiet", "encounterFocus" }, false)
      enterDungeon()

      env.fire("ENCOUNTER_START", 1, "Boss", 2, 5)
      assert.is_false(say("wait"))

      env.fire("ENCOUNTER_END", 1, "Boss", 2, 5, 0)
      assert.is_false(say("wait"))
    end)

    it("restores the normal level after a kill", function()
      enterDungeon()
      env.fire("ENCOUNTER_START", 1, "Boss", 2, 5)

      env.fire("ENCOUNTER_END", 1, "Boss", 2, 5, 1)

      assert.is_false(say("wait"))
    end)

    it("keeps chat muted for a while after a wipe", function()
      enterDungeon()
      env.fire("ENCOUNTER_START", 1, "Boss", 2, 5)
      env.fire("ENCOUNTER_END", 1, "Boss", 2, 5, 0)

      env.now = env.now + 10
      assert.is_true(say("wait"))

      env.now = env.now + 30
      assert.is_false(say("wait"))
    end)

    it("ignores encounters outside quiet groups", function()
      env.fire("ENCOUNTER_START", 1, "Boss", 2, 5)
      env.fire("ENCOUNTER_END", 1, "Boss", 2, 5, 0)
      enterDungeon()

      assert.is_false(say("wait"))
    end)
  end)

  describe("alarms", function()
    it("plays a loud ready check alarm", function()
      env.fire("READY_CHECK", "Leader", 35)

      assert.equal("Master", env.sounds[1].channel)
      assert.equal(1, env.flashes)
      assert.matches("Ready check", env.notices[1])
    end)

    it("alarms for role checks and queue pops too", function()
      env.fire("LFG_ROLE_CHECK_SHOW")
      env.fire("LFG_PROPOSAL_SHOW")

      assert.equal(2, #env.sounds)
    end)

    it("stays silent when the alarm is disabled", function()
      ns.UpdateSetting({ "quiet", "readyAlarm" }, false)

      env.fire("READY_CHECK", "Leader", 35)

      assert.equal(0, #env.sounds)
    end)
  end)

  describe("completion", function()
    it("says goodbye and offers a leave button", function()
      enterDungeon()

      env.fire("LFG_COMPLETION_REWARD")

      assert.equal(1, #env.sent)
      local button = env.buttonNamed("IntroVertLeaveButton")
      assert.is_true(button:IsShown())

      button:Click()

      assert.equal(1, env.leaves)
      assert.equal(LE_PARTY_CATEGORY_INSTANCE, env.leftCategory)
      assert.is_false(button:IsShown())
    end)

    it("hides the leave button once the group is left", function()
      enterDungeon()
      env.fire("LFG_COMPLETION_REWARD")
      env.isLFG = false

      leaveInstance()

      assert.is_false(env.buttonNamed("IntroVertLeaveButton"):IsShown())
    end)

    it("does nothing on completion outside quiet groups", function()
      env.fire("LFG_COMPLETION_REWARD")

      assert.equal(0, #env.sent)
      assert.is_nil(env.buttonNamed("IntroVertLeaveButton"))
    end)
  end)

  describe("slash commands", function()
    it("shows status", function()
      env.slash("quiet")

      assert.matches("dungeon=keywords", env.lastPrint())
    end)

    it("reports an invalid level", function()
      env.slash("quiet lfr loud")

      assert.matches("Unknown chat level 'loud'", env.lastPrint())
    end)

    it("prints quiet help for an unknown subcommand", function()
      env.slash("quiet what")

      assert.is_true(env.printed("/iv quiet log"))
      assert.is_false(env.printed("/iv help"))
    end)

    it("prints an empty log", function()
      env.slash("quiet log")

      assert.matches("Nothing hidden", env.lastPrint())
    end)

    it("turns quiet mode off while active", function()
      enterDungeon()

      env.slash("quiet off")

      assert.is_false(say("go go go"))
      assert.is_false(IntroVertDB.quiet.enabled.lfr)
    end)
  end)
end)
