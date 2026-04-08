-- HeadsUpCDM: Scan Blizzard action bars, find buttons by spellID, reparent into vertical column

local HUCDM = _G.HeadsUpCDM

local BAR_PREFIXES = {
    { prefix = "ActionButton",              count = 12 },
    { prefix = "MultiBarBottomLeftButton",  count = 12 },
    { prefix = "MultiBarBottomRightButton", count = 12 },
    { prefix = "MultiBarRightButton",       count = 12 },
    { prefix = "MultiBarLeftButton",        count = 12 },
    { prefix = "MultiBar5Button",           count = 12 },
    { prefix = "MultiBar6Button",           count = 12 },
    { prefix = "MultiBar7Button",           count = 12 },
}

----------------------------------------------------------------------
-- Resolve the spellID for a Blizzard action button
----------------------------------------------------------------------
local function GetButtonSpellID(btn)
    local slot = btn.action or (btn.GetAttribute and btn:GetAttribute("action"))
    if not slot then return nil end
    local ok, actionType, id, subType = pcall(GetActionInfo, slot)
    if not ok then return nil end
    if actionType == "spell" then
        return id
    elseif actionType == "macro" then
        if subType == "spell" then
            return id
        elseif GetMacroSpell then
            local ok2, macroSpell = pcall(GetMacroSpell, id)
            if ok2 then return macroSpell end
        end
    end
    return nil
end

----------------------------------------------------------------------
-- Find a Blizzard button with a given spellID
----------------------------------------------------------------------
local function FindButtonForSpell(spellID)
    for _, barInfo in ipairs(BAR_PREFIXES) do
        for i = 1, barInfo.count do
            local btn = _G[barInfo.prefix .. i]
            if btn then
                local btnSpell = GetButtonSpellID(btn)
                if btnSpell == spellID then
                    return btn
                end
            end
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

    -- Container frame for the action column
    local column = CreateFrame("Frame", "HUCDM_ActionColumn", layout)
    local spellCount = #preset.spells
    local totalHeight = (spellCount * iconSize) + ((spellCount - 1) * spacing)
    column:SetSize(iconSize, totalHeight)
    column:Show()

    self.actionColumn = column
    self.reparentedButtons = {}
    self.savedButtonState = {}
    self.actionRows = {}

    -- Scan and reparent
    self:ScanAndReparentButtons(preset, iconSize, spacing)

    -- Register column with layout system
    self:RegisterColumn("actions", column)

    return column
end

----------------------------------------------------------------------
-- Scan action bars and reparent matching buttons
----------------------------------------------------------------------
function HUCDM:ScanAndReparentButtons(preset, iconSize, spacing)
    local column = self.actionColumn
    if not column then return end

    local foundCount = 0

    for i, spellInfo in ipairs(preset.spells) do
        local btn = FindButtonForSpell(spellInfo.id)

        -- Create a row frame to hold the action button + paired buff icons
        local row = CreateFrame("Frame", "HUCDM_ActionRow" .. i, column)
        row:SetSize(iconSize, iconSize)
        local yOffset = -((i - 1) * (iconSize + spacing))
        row:SetPoint("TOPLEFT", column, "TOPLEFT", 0, yOffset)
        row.spellInfo = spellInfo

        self.actionRows[i] = row

        if btn then
            self:ReparentButton(btn, row, iconSize)
            foundCount = foundCount + 1
        else
            self:Print("Warning: " .. spellInfo.name .. " not found on action bars")
        end
    end

    if foundCount == 0 then
        self:Print("No matching spells found on action bars. Add your rotation spells to any bar.")
    end
end

----------------------------------------------------------------------
-- Reparent a single Blizzard button into a row
----------------------------------------------------------------------
function HUCDM:ReparentButton(btn, row, iconSize)
    -- Save original state for restore
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
-- Restore all reparented buttons to original positions
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
-- Re-scan (called on ACTIONBAR_SLOT_CHANGED etc.)
----------------------------------------------------------------------
function HUCDM:RescanActionButtons()
    if not self.currentPreset or not self.actionColumn then return end
    self:RestoreButtons()
    local settings = self.db.profile.layout.columns.actions
    self:ScanAndReparentButtons(self.currentPreset, 48, settings.spacing)
end
