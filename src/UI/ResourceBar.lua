-- HeadsUpCDM: Vertical Focus StatusBar with threshold colors and numeric overlay

local HUCDM = _G.HeadsUpCDM

----------------------------------------------------------------------
-- Create the resource bar
----------------------------------------------------------------------
function HUCDM:CreateResourceBar(totalHeight)
    local layout = self.layoutFrame
    if not layout then return end

    local barWidth = 14

    local column = CreateFrame("Frame", "HUCDM_ResourceColumn", layout)
    column:SetSize(barWidth, totalHeight)
    column:Show()

    -- StatusBar — two-point anchored so it auto-resizes with the column.
    -- (SetHeight on a single-anchor frame gets blocked by 12.0 taint when
    -- the sync runs from Blizzard's CDM hook chains, leaving the bar stuck
    -- at its creation size. Two-point anchors sidestep that entirely.)
    local bar = CreateFrame("StatusBar", "HUCDM_FocusBar", column)
    bar:SetPoint("TOPLEFT", column, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", 0, 0)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 100)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0, 1, 0)

    -- Background
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)

    -- Numeric overlay
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetFont(text:GetFont(), 10, "OUTLINE")
    text:SetTextColor(1, 1, 1, 1)
    text:SetRotation(math.rad(90))

    bar.text = text
    bar.column = column

    self.resourceBar = bar
    self.resourceColumn = column

    -- Register for power updates
    self:RegisterResourceEvents()

    -- Register column with layout system
    self:RegisterColumn("resource", column)

    return column
end

----------------------------------------------------------------------
-- Update focus bar value and color
----------------------------------------------------------------------
function HUCDM:UpdateResourceBar()
    local bar = self.resourceBar
    if not bar then return end

    local thresholds = self:GetResourceThresholds()

    pcall(function()
        local focus = UnitPower("player", Enum.PowerType.Focus)
        local maxFocus = UnitPowerMax("player", Enum.PowerType.Focus)
        if maxFocus == 0 then maxFocus = 100 end

        bar:SetMinMaxValues(0, maxFocus)
        bar:SetValue(focus)

        if self.db.profile.resourceBar.showText then
            bar.text:SetText(focus .. " / " .. maxFocus)
        else
            bar.text:SetText("")
        end

        if focus < thresholds.red then
            bar:SetStatusBarColor(0.8, 0.1, 0.1)
        elseif focus < thresholds.yellow then
            bar:SetStatusBarColor(0.9, 0.8, 0.1)
        else
            bar:SetStatusBarColor(0.1, 0.8, 0.1)
        end
    end)
end

----------------------------------------------------------------------
-- Get current thresholds (saved overrides or preset defaults)
----------------------------------------------------------------------
function HUCDM:GetResourceThresholds()
    local overrides = self.db.profile.resourceBar.thresholdOverrides
    if overrides and overrides.red then
        return overrides
    end

    if self.currentPreset and self.currentPreset.resourceThresholds then
        return self.currentPreset.resourceThresholds
    end

    return { red = 35, yellow = 70 }
end

----------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------
function HUCDM:RegisterResourceEvents()
    if not self.resourceEventFrame then
        self.resourceEventFrame = CreateFrame("Frame", "HUCDM_ResourceEvents", UIParent)
    end

    local f = self.resourceEventFrame
    f:RegisterEvent("UNIT_POWER_FREQUENT")
    f:SetScript("OnEvent", function(_, _, unit)
        if unit == "player" then
            self:UpdateResourceBar()
        end
    end)
end

----------------------------------------------------------------------
-- Teardown
----------------------------------------------------------------------
function HUCDM:DestroyResourceBar()
    if self.resourceEventFrame then
        self.resourceEventFrame:UnregisterAllEvents()
    end
    if self.resourceColumn then
        self.resourceColumn:Hide()
        self.resourceColumn = nil
    end
    self.resourceBar = nil
end
