-- Converts between editable separated text and string lists. Pure.
local _, ns = ...

local Lists = {}

-- Word lists (keywords) are split on commas; sentence lists (greetings,
-- replies) on semicolons, so a sentence can contain a comma.
Lists.WORDS = ","
Lists.SENTENCES = ";"

-- Chat messages longer than 255 bytes fail to send.
Lists.MAX_ENTRY_LENGTH = 255
Lists.MAX_ENTRIES = 20

-- Splits on `separator` (default Lists.WORDS), trims each entry, drops
-- blanks and case-insensitive duplicates (first spelling wins), and applies
-- the size limits. Always returns a new list.
function Lists.parse(text, separator)
  local result, seen = {}, {}
  for part in (text or ""):gmatch("[^" .. (separator or Lists.WORDS) .. "]+") do
    if #result >= Lists.MAX_ENTRIES then
      break
    end
    local entry = part:match("^%s*(.-)%s*$"):sub(1, Lists.MAX_ENTRY_LENGTH)
    local key = entry:lower()
    if entry ~= "" and not seen[key] then
      seen[key] = true
      result[#result + 1] = entry
    end
  end
  return result
end

function Lists.format(list, separator)
  return table.concat(list or {}, (separator or Lists.WORDS) .. " ")
end

-- Returns a new list with `item` appended, keeping at most `limit` entries
-- (the oldest are dropped).
function Lists.appendCapped(list, item, limit)
  local result = {}
  for index = math.max(1, #list - limit + 2), #list do
    result[#result + 1] = list[index]
  end
  result[#result + 1] = item
  return result
end

ns.Lists = Lists
