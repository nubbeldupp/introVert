-- Draggable minimap button (LibDBIcon look, no library). Click and tooltip
-- behaviour is shared with the addon compartment entry (Compartment.lua).
local addonName, ns = ...

local BUTTON_NAME = "IntroVertMinimapButton"
local ICON = "Interface\\Icons\\Ability_Rogue_Disguise"
local BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
local BACKGROUND = "Interface\\Minimap\\UI-Minimap-Background"
local HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
local BUTTON_SIZE = 31
local ICON_SIZE = 20
local BORDER_SIZE = 53
local EDGE_OFFSET = 10
local FRAME_LEVEL = 8
local HELP_LINES = { "/iv minimap - show or hide the minimap button" }

-- Lua 5.1 (WoW) has math.atan2; Lua 5.3+ uses math.atan(y, x).
local atan2 = math.atan2 or math.atan

local button
local dragAngle

local function settings()
  return ns.db.minimap
end

local function placeAt(angle)
  local radius = Minimap:GetWidth() / 2 + EDGE_OFFSET
  local radians = math.rad(angle)
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

local function cursorAngle()
  local centerX, centerY = Minimap:GetCenter()
  local cursorX, cursorY = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  return math.deg(atan2(cursorY / scale - centerY, cursorX / scale - centerX))
end

local function followCursor()
  dragAngle = cursorAngle()
  placeAt(dragAngle)
end

local function startDrag(self)
  dragAngle = nil
  self:SetScript("OnUpdate", followCursor)
end

local function stopDrag(self)
  self:SetScript("OnUpdate", nil)
  if dragAngle then
    ns.UpdateSetting({ "minimap", "angle" }, dragAngle)
  end
end

local function addTexture(parent, layer, path, size, point)
  local texture = parent:CreateTexture(nil, layer)
  texture:SetTexture(path)
  texture:SetSize(size, size)
  texture:SetPoint(point or "CENTER")
  return texture
end

local function createButton()
  local minimapButton = CreateFrame("Button", BUTTON_NAME, Minimap)
  minimapButton:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  minimapButton:SetFrameStrata("MEDIUM")
  minimapButton:SetFrameLevel(FRAME_LEVEL)
  minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  minimapButton:RegisterForDrag("LeftButton")
  minimapButton:SetHighlightTexture(HIGHLIGHT)
  addTexture(minimapButton, "BACKGROUND", BACKGROUND, ICON_SIZE)
  addTexture(minimapButton, "ARTWORK", ICON, ICON_SIZE)
  addTexture(minimapButton, "OVERLAY", BORDER, BORDER_SIZE, "TOPLEFT")
  minimapButton:SetScript("OnClick", function(_, mouseButton)
    IntroVert_OnAddonCompartmentClick(addonName, mouseButton)
  end)
  minimapButton:SetScript("OnEnter", function(self)
    IntroVert_OnAddonCompartmentEnter(addonName, self)
  end)
  minimapButton:SetScript("OnLeave", function()
    IntroVert_OnAddonCompartmentLeave()
  end)
  minimapButton:SetScript("OnDragStart", startDrag)
  minimapButton:SetScript("OnDragStop", stopDrag)
  return minimapButton
end

-- Applies the saved angle and visibility; runs after every settings change.
local function apply()
  if not button then
    return
  end
  placeAt(settings().angle)
  if settings().show then
    button:Show()
  else
    button:Hide()
  end
end

local function toggle()
  local show = not settings().show
  ns.UpdateSetting({ "minimap", "show" }, show)
  ns.Print(show and "Minimap button shown." or "Minimap button hidden.")
end

ns.On("ADDON_LOADED", function(_, loadedName)
  if loadedName == addonName and not button then
    button = createButton()
    apply()
  end
end)
ns.OnSettingsChanged(apply)

ns.Options.AddSection(function(ui)
  ui.header("General")
  ui.checkbox({ "minimap", "show" }, "Show minimap button",
    "Round introVert button on the minimap edge. Drag it to move it.")
end)

ns.RegisterCommand("minimap", toggle, HELP_LINES)
