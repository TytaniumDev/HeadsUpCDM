-- HeadsUpCDM: Vertical buff duration bars with icons at bottom

local HUCDM = _G.HeadsUpCDM

----------------------------------------------------------------------
-- Create a single buff bar
----------------------------------------------------------------------
local function CreateBuffBar(parent, buffInfo, index, barWidth, barHeight)
    local container = CreateFrame("Frame", "HUCDM_BuffBar" .. index, parent)
    container:SetSize(barWidth, barHeight)

    -- StatusBar (vertical, fills top-to-bottom as duration expires)
    local bar = CreateFrame("StatusBar", nil, container)
    local iconSize = barWidth
    bar:SetSize(barWidth, barHeight - iconSize - 2)
    bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    local color = buffInfo.color or { 0.5, 0.5, 0.5 }
    bar:SetStatusBarColor(color[1], color[2], color[3])

    -- Background
    local bgTex = bar:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(0, 0, 0, 0.6)

    -- Duration text (rotated vertical)
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetFont(text:GetFont(), 8, "OUTLINE")
    text:SetTextColor(1, 1, 1, 1)
    text:SetRotation(math.rad(90))

    -- Buff icon at bottom of bar
    local icon = container:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("BOTTOM", container, "BOTTOM", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local tex = C_Spell.GetSpellTexture(buffInfo.id)
    if tex then icon:SetTexture(tex) end

    container.bar = bar
    container.text = text
    container.icon = icon
    container.buffInfo = buffInfo

    return container
end

----------------------------------------------------------------------
-- Create all buff bars from preset defaults
----------------------------------------------------------------------
function HUCDM:CreateBuffBars(preset, totalHeight)
    local layout = self.layoutFrame
    if not layout then return end

    local barWidth = 18
    local barGap = 3
    local buffBarConfig = preset.buffBarDefaults or {}

    -- Container column for all buff bars
    local column = CreateFrame("Frame", "HUCDM_BuffBarsColumn", layout)
    local columnWidth = (#buffBarConfig * barWidth) + ((#buffBarConfig - 1) * barGap)
    if columnWidth <= 0 then columnWidth = 1 end
    column:SetSize(columnWidth, totalHeight)
    column:Show()

    self.buffBarColumn = column
    self.buffBarFrames = {}

    for i, buffInfo in ipairs(buffBarConfig) do
        local buffBar = CreateBuffBar(column, buffInfo, i, barWidth, totalHeight)
        local xOffset = (i - 1) * (barWidth + barGap)
        buffBar:SetPoint("TOPLEFT", column, "TOPLEFT", xOffset, 0)
        self.buffBarFrames[#self.buffBarFrames + 1] = buffBar
    end

    -- Register for aura updates
    self:RegisterBuffBarEvents()

    -- Register column with layout system
    self:RegisterColumn("buffBars", column)

    return column
end

----------------------------------------------------------------------
-- Update all buff bars based on current auras
----------------------------------------------------------------------
function HUCDM:UpdateBuffBars()
    for _, buffBar in ipairs(self.buffBarFrames or {}) do
        local buffInfo = buffBar.buffInfo
        -- Deferred texture fix for bar icons
        if not buffBar.textureLoaded and buffBar.icon then
            local tex = C_Spell.GetSpellTexture(buffInfo.id)
            if tex then
                buffBar.icon:SetTexture(tex)
                buffBar.textureLoaded = true
            end
        end
        pcall(function()
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(buffInfo.id)
            if aura and aura.duration and aura.duration > 0 then
                local remaining = aura.expirationTime - GetTime()
                local pct = remaining / aura.duration
                if pct < 0 then pct = 0 end
                if pct > 1 then pct = 1 end
                buffBar.bar:SetValue(pct)

                if self.db.profile.buffBars.showText then
                    buffBar.text:SetText(string.format("%.1f", remaining))
                else
                    buffBar.text:SetText("")
                end

                buffBar:SetAlpha(1.0)
            elseif aura then
                -- Permanent buff (no duration)
                buffBar.bar:SetValue(1)
                buffBar.text:SetText("")
                buffBar:SetAlpha(1.0)
            else
                -- Buff not active
                buffBar.bar:SetValue(0)
                buffBar.text:SetText("")
                buffBar:SetAlpha(0.3)
            end
        end)
    end
end

----------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------
function HUCDM:RegisterBuffBarEvents()
    if not self.buffBarEventFrame then
        self.buffBarEventFrame = CreateFrame("Frame", "HUCDM_BuffBarEvents", UIParent)
    end

    local f = self.buffBarEventFrame
    f:RegisterUnitEvent("UNIT_AURA", "player")
    f:SetScript("OnEvent", function()
        self:UpdateBuffBars()
    end)

    -- Ticker for smooth bar drain
    if self.buffBarTicker then self.buffBarTicker:Cancel() end
    self.buffBarTicker = C_Timer.NewTicker(0.1, function()
        self:UpdateBuffBars()
    end)
end

----------------------------------------------------------------------
-- Teardown
----------------------------------------------------------------------
function HUCDM:DestroyBuffBars()
    if self.buffBarEventFrame then
        self.buffBarEventFrame:UnregisterAllEvents()
    end
    if self.buffBarTicker then
        self.buffBarTicker:Cancel()
        self.buffBarTicker = nil
    end
    if self.buffBarColumn then
        self.buffBarColumn:Hide()
        self.buffBarColumn = nil
    end
    self.buffBarFrames = {}
end
