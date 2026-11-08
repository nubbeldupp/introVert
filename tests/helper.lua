-- Shared test helpers: load addon files the way the WoW client does,
-- passing (addonName, namespace) as the chunk varargs.
local ADDON_NAME = "IntroVert"

local helper = {}

function helper.load(path, ns)
  local chunk = assert(loadfile(path))
  chunk(ADDON_NAME, ns)
  return ns
end

-- Loads only the pure files (no WoW API needed).
function helper.loadPure(paths)
  local ns = {}
  for _, path in ipairs(paths) do
    helper.load(path, ns)
  end
  return ns
end

_G.IntroVertTestHelper = helper
return helper
