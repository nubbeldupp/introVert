-- Quiet Groups section of the introVert options page.
local _, ns = ...

local LEVEL_CHOICES = {
  { value = "off", label = "Show everything" },
  { value = "keywords", label = "Keywords and your name" },
  { value = "leader", label = "Group leader only" },
  { value = "all", label = "Hide everything" },
}

local LEVEL_TOOLTIP = "Which group chat lines stay visible. Raid warnings and your own lines always show."

local WIPE_MUTE_RANGE = { min = 0, max = 120, step = 5 }

local LIST_EDITORS = {
  { label = "Keywords", key = "keywords", prompt = "Lines containing any of these words always show (comma separated):" },
  { label = "Greetings", key = "greetings", prompt = "One of these is said when a new group forms (separate with ;):", separator = ns.Lists.SENTENCES },
  { label = "Goodbyes", key = "farewells", prompt = "One of these is said when the run is completed (separate with ;):", separator = ns.Lists.SENTENCES },
}

local function quiet(...)
  return { "quiet", ... }
end

local function addProfileControls(ui)
  ui.checkbox(quiet("enabled", "dungeon"), "Quiet in dungeons",
    "Turn on automatically in matchmade dungeons (Dungeon Finder).")
  ui.dropdown(quiet("chatLevel", "dungeon"), "Dungeon chat", LEVEL_CHOICES, LEVEL_TOOLTIP)
  ui.checkbox(quiet("enabled", "lfr"), "Quiet in Raid Finder",
    "Turn on automatically in Raid Finder and Timewalking raids.")
  ui.dropdown(quiet("chatLevel", "lfr"), "Raid Finder chat", LEVEL_CHOICES, LEVEL_TOOLTIP)
end

local function addBehaviorControls(ui)
  ui.checkbox(quiet("encounterFocus"), "Mute chat during boss fights",
    "Hide all group chat while a boss encounter is in progress.")
  ui.slider(quiet("wipeMuteSeconds"), "Mute after a wipe (seconds)", WIPE_MUTE_RANGE,
    "Keep chat muted this long after a wipe. Needs boss-fight muting; 0 turns it off.")
  ui.checkbox(quiet("greet"), "Greet the group", "Say one short line when a new group forms.")
  ui.checkbox(quiet("farewell"), "Say goodbye", "Say one short line when the run is completed.")
  ui.checkbox(quiet("readyAlarm"), "Loud ready check alarm",
    "Play a loud sound and flash the taskbar for ready checks, role checks and queue pops.")
end

local function addListEditors(ui)
  for _, editor in ipairs(LIST_EDITORS) do
    ui.button(editor.label, "Edit", function()
      ns.Options.EditList(quiet(editor.key), editor.prompt, editor.separator)
    end, editor.prompt)
  end
end

ns.Options.AddSection(function(ui)
  ui.header("Quiet Groups")
  addProfileControls(ui)
  addBehaviorControls(ui)
  addListEditors(ui)
end)
