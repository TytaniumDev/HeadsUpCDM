-- HeadsUpCDM: Hook Blizzard CDM Essential Cooldown frames and reposition them
-- into a vertical layout. Frames stay parented to the CDM viewer — we only
-- override their anchors. This survives frame recycling during spell transforms.

local HUCDM = _G.HeadsUpCDM

----------------------------------------------------------------------
-- Resolve the spellID for a CDM frame via C_CooldownViewer
----------------------------------------------------------------------
local function GetCDMFrameSpellID(frame)
    if not frame or not frame.cooldownID then return nil end
    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, frame.cooldownID)
    if not ok or not info then return nil end
    return info.overrideSpellID or info.spellID
end

----------------------------------------------------------------------
-- Build the action column (anchor frames only — CDM frames get repositioned)
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
    self.actionRows = {}
    self.cdmFrameMap = {}    -- spellID -> our row frame
    self.hookedCDMFrames = setmetatable({}, { __mode = "k" }) -- weak-keyed

    -- Create row anchor frames for each spell slot
    for i, spellInfo in ipairs(preset.spells) do
        local row = CreateFrame("Frame", "HUCDM_ActionRow" .. i, column)
        row:SetSize(iconSize, iconSize)
        local yOffset = -((i - 1) * (iconSize + spacing))
        row:SetPoint("TOPLEFT", column, "TOPLEFT", 0, yOffset)
        row.spellInfo = spellInfo

        self.actionRows[i] = row
        self.cdmFrameMap[spellInfo.id] = row
    end

    -- Hook CDM frames and do initial positioning
    self:HookCDMViewer()
    C_Timer.After(0.5, function() self:RepositionCDMFrames() end)
    C_Timer.After(2, function() self:RepositionCDMFrames() end)

    self:RegisterColumn("actions", column)
    return column
end

----------------------------------------------------------------------
-- Hook the CDM viewer to detect frame creation and cooldown changes
----------------------------------------------------------------------
function HUCDM:HookCDMViewer()
    -- Hook OnCooldownIDSet on the Essential mixin — fires when a frame gets
    -- assigned a cooldown (including after pool recycle)
    if CooldownViewerEssentialItemMixin
        and CooldownViewerEssentialItemMixin.OnCooldownIDSet
        and not self.cdmHooked then
        self.cdmHooked = true
        hooksecurefunc(CooldownViewerEssentialItemMixin, "OnCooldownIDSet", function()
            -- Defer to let Blizzard finish its layout pass
            C_Timer.After(0, function() self:RepositionCDMFrames() end)
        end)
    end

    -- Also hook the pool acquire in case frames get created fresh
    local viewer = _G["EssentialCooldownViewer"]
    if viewer and viewer.itemFramePool and not self.cdmPoolHooked then
        self.cdmPoolHooked = true
        if viewer.itemFramePool.Acquire then
            hooksecurefunc(viewer.itemFramePool, "Acquire", function()
                C_Timer.After(0, function() self:RepositionCDMFrames() end)
            end)
        end
    end
end

----------------------------------------------------------------------
-- Reposition all matching CDM Essential frames into our vertical layout
----------------------------------------------------------------------
function HUCDM:RepositionCDMFrames()
    local viewer = _G["EssentialCooldownViewer"]
    if not viewer or not viewer.itemFramePool then return end
    if not self.cdmFrameMap then return end

    local iconSize = 48

    for frame in viewer.itemFramePool:EnumerateActive() do
        local spellID = GetCDMFrameSpellID(frame)
        if spellID then
            local row = self.cdmFrameMap[spellID]
            if row then
                -- Reposition into our row (don't reparent — stay in CDM viewer)
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
                frame:SetSize(iconSize, iconSize)
                self.hookedCDMFrames[frame] = spellID
            end
        end
    end
end

----------------------------------------------------------------------
-- Restore all repositioned CDM frames (let CDM re-layout naturally)
----------------------------------------------------------------------
function HUCDM:RestoreButtons()
    -- We didn't reparent, so just clearing points is enough.
    -- The CDM will reposition frames on its next layout pass.
    local viewer = _G["EssentialCooldownViewer"]
    if viewer and viewer.itemFramePool then
        for frame in viewer.itemFramePool:EnumerateActive() do
            if self.hookedCDMFrames and self.hookedCDMFrames[frame] then
                frame:ClearAllPoints()
            end
        end
    end
    self.hookedCDMFrames = setmetatable({}, { __mode = "k" })

    -- Trigger CDM to re-layout its frames
    if viewer and viewer.Layout then
        pcall(viewer.Layout, viewer)
    end
end

----------------------------------------------------------------------
-- Teardown
----------------------------------------------------------------------
function HUCDM:DestroyActionColumn()
    self:RestoreButtons()
    if self.actionColumn then
        self.actionColumn:Hide()
        self.actionColumn = nil
    end
    self.actionRows = {}
    self.cdmFrameMap = {}
end

----------------------------------------------------------------------
-- Re-scan (called on events)
----------------------------------------------------------------------
function HUCDM:RescanActionButtons()
    if not self.currentPreset or not self.actionColumn then return end
    self:RepositionCDMFrames()
end
