-- Guild recruitment detection for chat (English and German). Pure.
local _, ns = ...

local Spam = {}

-- Any of these alone marks a recruitment message.
local ALWAYS = { "recruit", "rekrut" }

-- A guild word plus one of the context words marks a recruitment message.
local GUILD_WORDS = { "guild", "gilde" }
local GUILD_CONTEXT = {
  "join", "looking for", "lf ", "lfm", "members", "apply", "discord", "raiders",
  "sucht", "suchen", "mitglieder", "verstärkung", "bewerb",
}

local function containsAny(text, words)
  for _, word in ipairs(words) do
    if text:find(word, 1, true) then
      return true
    end
  end
  return false
end

function Spam.isRecruitment(text)
  if type(text) ~= "string" then
    return false
  end
  local lower = text:lower()
  if containsAny(lower, ALWAYS) then
    return true
  end
  return containsAny(lower, GUILD_WORDS) and containsAny(lower, GUILD_CONTEXT)
end

ns.Spam = Spam
