-- Decides which Quiet profile (if any) applies to the current instance.
-- Pure: takes a context snapshot, never calls the WoW API itself.
local _, ns = ...

local Profile = {}

Profile.DUNGEON = "dungeon"
Profile.LFR = "lfr"
Profile.ALL = { Profile.DUNGEON, Profile.LFR }

-- Raid difficulties that are matchmade with strangers:
-- 7 = legacy LFR, 17 = Raid Finder, 33 = Timewalking raid, 151 = Timewalking LFR.
local LFR_LIKE_DIFFICULTIES = { [7] = true, [17] = true, [33] = true, [151] = true }

-- 205 = Follower dungeon (NPC party, nothing to mute).
local FOLLOWER_DIFFICULTIES = { [205] = true }

-- ctx: { inInstance, isLFG, instanceType, difficultyID }
function Profile.resolve(ctx)
  if not ctx or not ctx.inInstance or not ctx.isLFG then
    return nil
  end
  if FOLLOWER_DIFFICULTIES[ctx.difficultyID] then
    return nil
  end
  if ctx.instanceType == "party" then
    return Profile.DUNGEON
  end
  if ctx.instanceType == "raid" and LFR_LIKE_DIFFICULTIES[ctx.difficultyID] then
    return Profile.LFR
  end
  return nil
end

function Profile.isValid(name)
  return name == Profile.DUNGEON or name == Profile.LFR
end

function Profile.isEnabled(profile, settings)
  return Profile.isValid(profile) and settings.enabled[profile] == true
end

ns.QuietProfile = Profile
