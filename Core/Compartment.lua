-- Minimap button via the game's built-in addon compartment (the addon list
-- button on the minimap). The TOC names these global functions:
-- left-click toggles the window, right-click opens the options.
local _, ns = ...

local TITLE = "introVert"
local TOOLTIP_LINES = { "Left-click: open the window", "Right-click: options" }
local WHITE = 1

function IntroVert_OnAddonCompartmentClick(_, mouseButton)
  if mouseButton == "RightButton" then
    ns.Options.Open()
  else
    ns.Window.Toggle()
  end
end

function IntroVert_OnAddonCompartmentEnter(_, menuButtonFrame)
  GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
  GameTooltip:SetText(TITLE)
  for _, line in ipairs(TOOLTIP_LINES) do
    GameTooltip:AddLine(line, WHITE, WHITE, WHITE)
  end
  GameTooltip:Show()
end

function IntroVert_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end
