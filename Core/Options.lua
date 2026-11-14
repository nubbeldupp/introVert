-- Builds the introVert page in Options > AddOns from sections that modules
-- register. Every control reads and writes ns.db through proxy settings, so
-- the panel and the slash commands always show the same values.
local addonName, ns = ...

local CATEGORY_NAME = "introVert"
local VARIABLE_PREFIX = "IntroVert_"
local LIST_POPUP = "INTROVERT_EDIT_LIST"
local LIST_POPUP_WIDTH = 350
local UNAVAILABLE = "Options panel is not available in this client; use /iv help."
local BUILD_FAILED = "Options panel could not be built; slash commands still work (/iv help)."
local IN_COMBAT = "You can open the options after combat."
local HELP_LINES = { "/iv options - open the settings panel (also /iv config)" }

local Options = {}
local sections = {}
local category

-- builder(ui) is called once when the panel is built. `ui` offers
-- header, checkbox, dropdown, slider and button helpers.
function Options.AddSection(builder)
  sections[#sections + 1] = builder
end

local function variableName(path)
  return VARIABLE_PREFIX .. table.concat(path, "_")
end

local function registerSetting(path, varType, label)
  return Settings.RegisterProxySetting(
    category, variableName(path), varType, label,
    ns.Defaults.get(ns.Defaults.values, path),
    function() return ns.Defaults.get(ns.db, path) end,
    function(value) ns.UpdateSetting(path, value) end
  )
end

local function dropdownOptions(choices)
  return function()
    local container = Settings.CreateControlTextContainer()
    for _, choice in ipairs(choices) do
      container:Add(choice.value, choice.label)
    end
    return container:GetData()
  end
end

local function sliderOptions(range)
  local options = Settings.CreateSliderOptions(range.min, range.max, range.step)
  if MinimalSliderWithSteppersMixin then
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  end
  return options
end

local function newBuilder(layout)
  local ui = {}
  function ui.header(text)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
  end
  function ui.checkbox(path, label, tooltip)
    Settings.CreateCheckbox(category, registerSetting(path, Settings.VarType.Boolean, label), tooltip)
  end
  function ui.dropdown(path, label, choices, tooltip)
    local setting = registerSetting(path, Settings.VarType.String, label)
    Settings.CreateDropdown(category, setting, dropdownOptions(choices), tooltip)
  end
  function ui.slider(path, label, range, tooltip)
    local setting = registerSetting(path, Settings.VarType.Number, label)
    Settings.CreateSlider(category, setting, sliderOptions(range), tooltip)
  end
  function ui.button(label, buttonText, onClick, tooltip)
    layout:AddInitializer(CreateSettingsButtonInitializer(label, buttonText, onClick, tooltip, true))
  end
  return ui
end

local function build()
  local newCategory, layout = Settings.RegisterVerticalLayoutCategory(CATEGORY_NAME)
  category = newCategory
  local ui = newBuilder(layout)
  for _, section in ipairs(sections) do
    section(ui)
  end
  Settings.RegisterAddOnCategory(newCategory)
end

function Options.Build()
  if not (Settings and Settings.RegisterVerticalLayoutCategory) then
    ns.Print(UNAVAILABLE)
    return
  end
  local ok, err = pcall(build)
  if not ok then
    category = nil
    geterrorhandler()(err)
    ns.Print(BUILD_FAILED)
  end
end

function Options.Open()
  if not category then
    ns.Print(UNAVAILABLE)
    return
  end
  if InCombatLockdown() then
    ns.Print(IN_COMBAT)
    return
  end
  Settings.OpenToCategory(category:GetID())
end

-- List editor popup ------------------------------------------------------------

local function editBoxOf(popup)
  return popup.EditBox or popup.editBox
end

local function saveList(popup, data)
  ns.UpdateSetting(data.path, ns.Lists.parse(editBoxOf(popup):GetText(), data.separator))
end

local function ensureListPopup()
  if StaticPopupDialogs[LIST_POPUP] then
    return
  end
  StaticPopupDialogs[LIST_POPUP] = {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    editBoxWidth = LIST_POPUP_WIDTH,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(popup, data)
      local editBox = editBoxOf(popup)
      editBox:SetText(ns.Lists.format(ns.Defaults.get(ns.db, data.path), data.separator))
      editBox:HighlightText()
    end,
    OnAccept = saveList,
    EditBoxOnEnterPressed = function(editBox, data)
      local popup = editBox:GetParent()
      saveList(popup, data)
      popup:Hide()
    end,
    EditBoxOnEscapePressed = function(editBox)
      editBox:GetParent():Hide()
    end,
  }
end

-- Opens a popup to edit the string list stored at `path` as separated text
-- (separator: ns.Lists.WORDS by default, ns.Lists.SENTENCES for phrases).
function Options.EditList(path, prompt, separator)
  ensureListPopup()
  StaticPopup_Show(LIST_POPUP, prompt, nil, { path = path, separator = separator })
end

ns.On("ADDON_LOADED", function(_, loadedName)
  if loadedName == addonName then
    Options.Build()
  end
end)

ns.RegisterCommand("options", Options.Open, HELP_LINES)
ns.RegisterCommand("config", Options.Open)

ns.Options = Options
