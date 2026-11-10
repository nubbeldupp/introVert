-- The introVert window: one movable, scrollable frame with a tab per view.
-- Modules register views with Window.AddView(key, title, provider), where
-- provider(isExpanded) returns the lines to show. Rows wrapped in
-- Window.ToggleLink(key, text) open and close on click; isExpanded(key) tells
-- the provider which are open. Created lazily on first open.
local _, ns = ...

local WINDOW_NAME = "IntroVertWindow"
-- Wide enough for six tab buttons in one row.
local WIDTH = 640
local HEIGHT = 440
local PADDING = 16
local TITLE_OFFSET_Y = -16
local TABS_OFFSET_Y = -44
local CONTENT_OFFSET_Y = -76
local SCROLLBAR_SPACE = 34
local CONTENT_WIDTH = WIDTH - PADDING - SCROLLBAR_SPACE - PADDING
local TAB_WIDTH = 96
local TAB_HEIGHT = 22
local TAB_GAP = 4
local HEADER_COLOR = "|cffffd100"
local COLOR_END = "|r"
local DETAIL_PREFIX = "  "
local TOGGLE_LINK_PREFIX = "introvert:toggle:"
local HELP_LINES = { "/iv window - show or hide the introVert window" }

local BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local TITLE = "introVert"

local Window = {}
local views = {}
local frame, content, tabButtons, titleText
local currentKey

function Window.AddView(key, title, provider)
  views[#views + 1] = { key = key, title = title, provider = provider, expanded = {} }
end

-- Header lines in gold; indented detail lines and empty spacers plain.
function Window.Format(lines)
  local formatted = {}
  for index, line in ipairs(lines) do
    local isPlain = line == "" or line:sub(1, #DETAIL_PREFIX) == DETAIL_PREFIX
    formatted[index] = isPlain and line or (HEADER_COLOR .. line .. COLOR_END)
  end
  return table.concat(formatted, "\n")
end

-- Clickable text that opens or closes row `key` of the current view.
function Window.ToggleLink(key, text)
  return ("|H%s%s|h%s|h"):format(TOGGLE_LINK_PREFIX, key, text)
end

local function findView(key)
  for _, view in ipairs(views) do
    if view.key == key then
      return view
    end
  end
  return nil
end

local function render()
  local view = findView(currentKey)
  if not view then
    return
  end
  titleText:SetText(TITLE .. " - " .. view.title)
  local function isExpanded(rowKey)
    return view.expanded[rowKey] == true
  end
  content.text:SetText(Window.Format(view.provider(isExpanded)))
  content:SetHeight(content.text:GetStringHeight() + PADDING)
  -- Every tab stays clickable; the open one glows.
  for key, button in pairs(tabButtons) do
    if key == currentKey then
      button:LockHighlight()
    else
      button:UnlockHighlight()
    end
  end
end

-- Frame construction -------------------------------------------------------------

local function createFrame()
  local window = CreateFrame("Frame", WINDOW_NAME, UIParent, "BackdropTemplate")
  window:SetSize(WIDTH, HEIGHT)
  window:SetPoint("CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetBackdrop(BACKDROP)
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)

  titleText = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titleText:SetPoint("TOP", 0, TITLE_OFFSET_Y)
  titleText:SetText(TITLE)

  local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  window:Hide()
  table.insert(UISpecialFrames, WINDOW_NAME)
  return window
end

local function createTabs(parent)
  local buttons = {}
  for index, view in ipairs(views) do
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(TAB_WIDTH, TAB_HEIGHT)
    button:SetPoint("TOPLEFT", PADDING + (index - 1) * (TAB_WIDTH + TAB_GAP), TABS_OFFSET_Y)
    button:SetText(view.title)
    button:SetScript("OnClick", function() Window.Show(view.key) end)
    buttons[view.key] = button
  end
  return buttons
end

local function createContent(parent)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", PADDING, CONTENT_OFFSET_Y)
  scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_SPACE, PADDING)

  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(CONTENT_WIDTH, 1)
  child:SetHyperlinksEnabled(true)
  child:SetScript("OnHyperlinkClick", function(_, link) Window.ClickLink(link) end)
  scroll:SetScrollChild(child)

  local text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("TOPLEFT")
  text:SetWidth(CONTENT_WIDTH)
  text:SetJustifyH("LEFT")
  child.text = text
  return child
end

local function ensureFrame()
  if frame then
    return
  end
  frame = createFrame()
  tabButtons = createTabs(frame)
  content = createContent(frame)
end

-- Public API ---------------------------------------------------------------------

-- Opens on `key`, or the last view used, or the first registered view.
function Window.Show(key)
  ensureFrame()
  currentKey = key or currentKey or (views[1] and views[1].key)
  frame:Show()
  render()
end

function Window.Hide()
  if frame then
    frame:Hide()
  end
end

function Window.IsShown()
  return frame ~= nil and frame:IsShown()
end

function Window.Toggle()
  if Window.IsShown() then
    Window.Hide()
  else
    Window.Show()
  end
end

-- Redraws the open view; does nothing while the window is hidden.
function Window.Refresh()
  if Window.IsShown() then
    render()
  end
end

-- Handles a click on a link in the open view; foreign links are ignored.
-- Opened rows stay open per view for the session.
function Window.ClickLink(link)
  local rowKey = Window.IsShown() and link:match("^" .. TOGGLE_LINK_PREFIX .. "(.+)$")
  local view = rowKey and findView(currentKey)
  if not view then
    return
  end
  -- Replace the table instead of mutating it.
  local expanded = {}
  for key, isOpen in pairs(view.expanded) do
    expanded[key] = isOpen
  end
  expanded[rowKey] = not view.expanded[rowKey] or nil
  view.expanded = expanded
  render()
end

function Window.CurrentView()
  return currentKey
end

function Window.GetText()
  return content and content.text:GetText()
end

function Window.GetTitle()
  return titleText and titleText:GetText()
end

ns.OnSettingsChanged(Window.Refresh)
ns.RegisterCommand("window", Window.Toggle, HELP_LINES)

ns.Window = Window
