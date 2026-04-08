-- HeadsUpCDM: Scan Blizzard CDM Essential Cooldown frames, reparent into vertical column
-- Uses the Cooldown Manager's EssentialCooldownViewer instead of action bar buttons,
-- so the player's action bars remain untouched.

local HUCDM = _G.HeadsUpCDM

----------------------------------------------------------------------
-- Resolve the spellID for a CDM Essential frame via C_CooldownViewer
----------------------------------------------------------------------
local function GetCDMFrameSpellID(frame)
    if not frame or not frame.cooldownID then return nil end
    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCooldownInfo then return nil end

    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, frame.cooldownID)
    if not ok or not info then return nil end

    -- overrideSpellID is the current display spell (may differ from base due to talents)
    return info.overrideSpellID or info.spellID
end

----------------------------------------------------------------------
-- Get all active CDM Essential frames from the viewer's item pool
----------------------------------------------------------------------
local function GetEssentialFrames()
    local viewer = _G["EssentialCooldownViewer"]
    if not viewer or not viewer.itemFramePool then return {} end

    local frames = {}
    for frame in viewer.itemFramePool:EnumerateActive() do
        frames[#frames + 1] = frame
    end
    return frames
end

----------------------------------------------------------------------
-- Find a CDM Essential frame matching a given spellID
----------------------------------------------------------------------
local function FindCDMFrameForSpell(spellID)
    local frames = GetEssentialFrames()
    for _, frame in ipairs(frames) do
        local frameSpell = GetCDMFrameSpellID(frame)
        if frameSpell == spellID then
            return frame
        end
    end
    return nil
end

----------------------------------------------------------------------
-- Build the action column
----------------------------------------------------------------------
function HUCDM:CreateActionColumn(preset)
    local layout = self.layoutFrame
    if not layout then return end

    local settings = self.db.profile.layout.columns.actions
    local iconSize = 48
    local spacing = settings.spacing

    local column = CreateFrame("Frame", "HUCDM_ActionColumn", layout)
    local spellCount = #preset.spells
    local totalHeight = (spellCount * iconSize) + ((spellCount - 1) * spacing)
    column:SetSize(iconSize, totalHeight)
    column:Show()

    self.actionColumn = column
    self.reparentedButtons = {}
    self.savedButtonState = {}
    self.actionRows = {}

    self:ScanAndReparentCDMFrames(preset, iconSize, spacing)

    self:RegisterColumn("actions", column)

    return column
end

----------------------------------------------------------------------
-- Scan CDM Essential frames and reparent matching ones
----------------------------------------------------------------------
function HUCDM:ScanAndReparentCDMFrames(preset, iconSize, spacing)
    local column = self.actionColumn
    if not column then return end

    local foundCount = 0

    for i, spellInfo in ipairs(preset.spells) do
        local row = CreateFrame("Frame", "HUCDM_ActionRow" .. i, column)
        row:SetSize(iconSize, iconSize)
        local yOffset = -((i - 1) * (iconSize + spacing))
        row:SetPoint("TOPLEFT", column, "TOPLEFT", 0, yOffset)
        row.spellInfo = spellInfo

        self.actionRows[i] = row

        local cdmFrame = FindCDMFrameForSpell(spellInfo.id)
        if cdmFrame then
            self:ReparentButton(cdmFrame, row, iconSize)
            foundCount = foundCount + 1
        else
            -- Try with base spell (talent transforms may change the ID)
            local baseID = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(spellInfo.id)
            if baseID and baseID ~= spellInfo.id then
                cdmFrame = FindCDMFrameForSpell(baseID)
                if cdmFrame then
                    self:ReparentButton(cdmFrame, row, iconSize)
                    foundCount = foundCount + 1
                end
            end
            if not cdmFrame then
                self:Print("Warning: " .. spellInfo.name
                    .. " not found in Essential Cooldowns. Add it via Edit Mode.")
            end
        end
    end

    if foundCount == 0 then
        self:Print("No matching Essential Cooldowns found. "
            .. "Open Edit Mode and add your rotation spells to Essential Cooldowns.")
    end
end

----------------------------------------------------------------------
-- Reparent a single CDM frame into a row
----------------------------------------------------------------------
function HUCDM:ReparentButton(btn, row, iconSize)
    local numPoints = btn:GetNumPoints()
    local origPoints = {}
    for i = 1, numPoints do
        origPoints[i] = { btn:GetPoint(i) }
    end

    self.savedButtonState[btn] = {
        parent = btn:GetParent(),
        points = origPoints,
        width = btn:GetWidth(),
        height = btn:GetHeight(),
    }

    btn:ClearAllPoints()
    btn:SetParent(row)
    btn:SetSize(iconSize, iconSize)
    btn:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    btn:Show()

    self.reparentedButtons[#self.reparentedButtons + 1] = btn
end

----------------------------------------------------------------------
-- Restore all reparented frames to original positions
----------------------------------------------------------------------
function HUCDM:RestoreButtons()
    for _, btn in ipairs(self.reparentedButtons or {}) do
        local saved = self.savedButtonState[btn]
        if saved then
            btn:ClearAllPoints()
            btn:SetParent(saved.parent)
            btn:SetSize(saved.width, saved.height)
            for _, pt in ipairs(saved.points) do
                btn:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
            end
        end
    end
    self.reparentedButtons = {}
    self.savedButtonState = {}
end

----------------------------------------------------------------------
-- Teardown action column
----------------------------------------------------------------------
function HUCDM:DestroyActionColumn()
    self:RestoreButtons()
    if self.actionColumn then
        self.actionColumn:Hide()
        self.actionColumn = nil
    end
    self.actionRows = {}
end

----------------------------------------------------------------------
-- Re-scan (called when CDM frames change)
----------------------------------------------------------------------
function HUCDM:RescanActionButtons()
    if not self.currentPreset or not self.actionColumn then return end
    self:RestoreButtons()
    local settings = self.db.profile.layout.columns.actions
    self:ScanAndReparentCDMFrames(self.currentPreset, 48, settings.spacing)
end
