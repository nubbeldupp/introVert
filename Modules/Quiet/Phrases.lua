-- Picks a greeting/farewell line. Pure: the random source is injected.
local _, ns = ...

local Phrases = {}

-- random(n) must return an integer in [1, n] (math.random works).
function Phrases.pick(list, random)
  local usable = {}
  for _, phrase in ipairs(list or {}) do
    if type(phrase) == "string" and phrase:match("%S") then
      usable[#usable + 1] = phrase
    end
  end
  if #usable == 0 then
    return nil
  end
  return usable[random(#usable)]
end

ns.QuietPhrases = Phrases
