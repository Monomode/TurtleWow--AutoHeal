-- ====================================
-- AutoHeal GUI Sub-Addon
-- ====================================

-- Create the main GUI frame
local gui = CreateFrame("Frame", "AutoHealConfigFrame", UIParent)
gui:SetWidth(220)
gui:SetHeight(120)
gui:SetPoint("CENTER", 0, 0)
gui:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
gui:SetMovable(true)
gui:EnableMouse(true)
gui:RegisterForDrag("LeftButton")
gui:SetScript("OnDragStart", gui.StartMoving)
gui:SetScript("OnDragStop", gui.StopMovingOrSizing)
gui:Hide()

local title = gui:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -12)
title:SetText("AutoHeal Settings")

local text = gui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("TOPLEFT", 16, -40)
text:SetText("GUI connected to AutoHeal core.")

-- ====================================
-- Minimap Button
-- ====================================

local mini = CreateFrame("Button", "AutoHealMiniButton", Minimap)
mini:SetWidth(32)
mini:SetHeight(32)
mini:SetFrameStrata("MEDIUM")
mini:SetFrameLevel(8)

mini:SetNormalTexture("Interface\\Icons\\Spell_Holy_Heal")
mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mini:SetPoint("TOPLEFT", Minimap, "TOPLEFT")

mini:RegisterForDrag("LeftButton")
mini:SetMovable(true)
mini:SetScript("OnDragStart", function(self) self:StartMoving() end)
mini:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- Toggle GUI visibility
mini:SetScript("OnClick", function()
    if gui:IsShown() then
        gui:Hide()
    else
        gui:Show()
    end
end)

-- Tooltip
mini:SetScript("OnEnter", function()
    GameTooltip:SetOwner(mini, "ANCHOR_LEFT")
    GameTooltip:AddLine("AutoHeal GUI", 1, 1, 1)
    GameTooltip:AddLine("Click to toggle settings", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
mini:SetScript("OnLeave", function() GameTooltip:Hide() end)

DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AutoHeal GUI loaded!|r Click the minimap button to open settings.")

