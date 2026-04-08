-- HeadsUpCDM: Paired buff icons displayed next to their associated action bar spells

local HUCDM = _G.HeadsUpCDM

local GLOW_BORDER = 2

----------------------------------------------------------------------
-- Create a single buff icon frame
----------------------------------------------------------------------
local function CreateBuffIcon(parent, buffInfo, _index, iconSize)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(iconSize, iconSize)

    -- Spell texture
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon = icon

    -- Try to set texture now; may need deferred update if spell not yet loaded
    local tex = C_Spell.GetSpellTexture(buffInfo.id)
    if tex then icon:SetTexture(tex) end

    -- Highlighted border for active state
    local border = CreateFrame("Frame", nil, f)
    border:SetFrameLevel(f:GetFrameLevel() + 2)
    border:SetPoint("TOPLEFT", f, "TOPLEFT", -GLOW_BORDER, GLOW_BORDER)
    border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", GLOW_BORDER, -GLOW_BORDER)

    local dirs = {
        { "TOPLEFT", "TOPRIGHT", 0, 0, 0, -GLOW_BORDER },
        { "BOTTOMLEFT", "BOTTOMRIGHT", 0, GLOW_BORDER, 0, 0 },
        { "TOPLEFT", "BOTTOMLEFT", 0, 0, GLOW_BORDER, 0 },
        { "TOPRIGHT", "BOTTOMRIGHT", -GLOW_BORDER, 0, 0, 0 },
    }
    for i = 1, #dirs do
        local d = dirs[i]
        local tex2 = border:CreateTexture(nil, "OVERLAY")
        tex2:SetPoint(d[1], border, d[1], d[3], d[4])
        tex2:SetPoint(d[2], border, d[2], d[5], d[6])
        tex2:SetColorTexture(0.2, 0.8, 0.2, 0.9)
    end
    border:Hide()
    f.border = border

    -- Countdown text
    local cdText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cdText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    cdText:SetFont(cdText:GetFont(), 12, "OUTLINE")
    cdText:SetTextColor(1, 0.84, 0, 1)
    f.cdText = cdText

    f.buffInfo = buffInfo
    f:Hide()  -- hidden by default; shown when buff is active

    return f
end

----------------------------------------------------------------------
-- Create buff icons for all action rows
----------------------------------------------------------------------
function HUCDM:CreateBuffIcons(preset)
    self.buffIconFrames = {}

    local iconSize = 48  -- same as action icons per PRD
    local iconGap = 4

    for rowIdx, row in ipairs(self.actionRows or {}) do
        local spellInfo = preset.spells[rowIdx]
        if spellInfo and spellInfo.pairedBuffs and #spellInfo.pairedBuffs > 0 then
            local rowIcons = {}
            for buffIdx, buffInfo in ipairs(spellInfo.pairedBuffs) do
                local buffIcon = CreateBuffIcon(row, buffInfo, buffIdx, iconSize)
                local xOffset = iconSize + ((buffIdx - 1) * (iconSize + iconGap)) + iconGap
                buffIcon:SetPoint("TOPLEFT", row, "TOPLEFT", xOffset, 0)
                rowIcons[#rowIcons + 1] = buffIcon
            end
            self.buffIconFrames[rowIdx] = rowIcons
        end
    end

    -- Register for aura updates
    self:RegisterBuffIconEvents()
end

----------------------------------------------------------------------
-- Update all buff icons based on current auras
----------------------------------------------------------------------
function HUCDM:UpdateBuffIcons()
    local isEditMode = not self.db.profile.locked

    for _, rowIcons in pairs(self.buffIconFrames or {}) do
        for _, buffIcon in ipairs(rowIcons) do
            local buffInfo = buffIcon.buffInfo
            local aura = nil
            pcall(function()
                aura = C_UnitAuras.GetPlayerAuraBySpellID(buffInfo.id)
            end)

            -- Deferred texture fix: retry if icon was a placeholder
            if not buffIcon.textureLoaded then
                local tex = C_Spell.GetSpellTexture(buffInfo.id)
                if tex then
                    buffIcon.icon:SetTexture(tex)
                    buffIcon.textureLoaded = true
                end
            end

            if aura then
                -- Buff is active
                buffIcon:Show()
                buffIcon:SetAlpha(1.0)
                buffIcon.border:Show()

                -- Update countdown text
                pcall(function()
                    if aura.expirationTime and aura.expirationTime > 0 then
                        local remaining = aura.expirationTime - GetTime()
                        if remaining > 0 then
                            buffIcon.cdText:SetText(string.format("%.1f", remaining))
                        else
                            buffIcon.cdText:SetText("")
                        end
                    else
                        buffIcon.cdText:SetText("")  -- permanent buff
                    end
                end)
            elseif isEditMode then
                -- In edit mode: show dimmed
                buffIcon:Show()
                buffIcon:SetAlpha(0.3)
                buffIcon.border:Hide()
                buffIcon.cdText:SetText("")
            else
                -- In locked mode: hide completely
                buffIcon:Hide()
            end
        end
    end
end

----------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------
function HUCDM:RegisterBuffIconEvents()
    if not self.buffIconEventFrame then
        self.buffIconEventFrame = CreateFrame("Frame", "HUCDM_BuffIconEvents", UIParent)
    end

    local f = self.buffIconEventFrame
    f:RegisterUnitEvent("UNIT_AURA", "player")
    f:SetScript("OnEvent", function()
        self:UpdateBuffIcons()
    end)

    -- Ticker for countdown text updates
    if self.buffIconTicker then self.buffIconTicker:Cancel() end
    self.buffIconTicker = C_Timer.NewTicker(0.1, function()
        self:UpdateBuffIcons()
    end)
end

----------------------------------------------------------------------
-- Teardown
----------------------------------------------------------------------
function HUCDM:DestroyBuffIcons()
    if self.buffIconEventFrame then
        self.buffIconEventFrame:UnregisterAllEvents()
    end
    if self.buffIconTicker then
        self.buffIconTicker:Cancel()
        self.buffIconTicker = nil
    end
    for _, rowIcons in pairs(self.buffIconFrames or {}) do
        for _, icon in ipairs(rowIcons) do
            icon:Hide()
        end
    end
    self.buffIconFrames = {}
end
