-- HeadsUpCDM: Reposition Blizzard CDM Essential Cooldown frames into a vertical layout.
-- Syncs the EssentialCooldownViewer to our column frame, then overrides individual
-- icon positions. Hooks SetPoint to enforce positions when Blizzard re-layouts.
-- Based on patterns from EllesmereUI's CDM reanchor system.

local HUCDM = _G.HeadsUpCDM

-- Per-frame data (weak-keyed so GC cleans up recycled frames)
local frameData = setmetatable({}, { __mode = "k" })

local REANCHOR_THROTTLE = 0.15
local reanchorDirty = false
local lastReanchorTime = 0

----------------------------------------------------------------------
-- Resolve the spellID for a CDM frame
----------------------------------------------------------------------
local function GetCDMFrameSpellIDs(frame)
    if not frame or not frame.cooldownID then return nil, nil end
    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, frame.cooldownID)
    if not ok or not info then return nil, nil end
    return info.overrideSpellID, info.spellID
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
    self.actionRows = {}
    self.cdmSpellSlots = {}  -- spellID -> { row, index }

    -- Create row anchor frames for each spell slot
    for i, spellInfo in ipairs(preset.spells) do
        local row = CreateFrame("Frame", "HUCDM_ActionRow" .. i, column)
        row:SetSize(iconSize, iconSize)
        local yOffset = -((i - 1) * (iconSize + spacing))
        row:SetPoint("TOPLEFT", column, "TOPLEFT", 0, yOffset)
        row.spellInfo = spellInfo

        self.actionRows[i] = row
        self.cdmSpellSlots[spellInfo.id] = { row = row, index = i }
    end

    -- Sync the CDM viewer to our column and install hooks
    self:SetupCDMHooks()

    -- Deferred initial positioning (next frame, let CDM finish its layout)
    C_Timer.After(0, function() self:ReanchorCDMFrames() end)

    self:RegisterColumn("actions", column)
    return column
end

----------------------------------------------------------------------
-- Sync CDM viewer to our column and install hooks
----------------------------------------------------------------------
function HUCDM:SetupCDMHooks()
    if self.cdmHooksInstalled then return end

    local viewer = _G["EssentialCooldownViewer"]
    if not viewer then return end

    self.cdmHooksInstalled = true

    -- Anchor the viewer itself to our column so frames render in our space
    local function SyncViewerToColumn()
        if InCombatLockdown() then return end
        local col = self.actionColumn
        if not col then return end
        viewer:ClearAllPoints()
        viewer:SetPoint("TOPLEFT", col, "TOPLEFT", 0, 0)
        viewer:SetPoint("BOTTOMRIGHT", col, "BOTTOMRIGHT", 0, 0)
    end

    -- Hook Layout to re-sync after Blizzard repositions the viewer
    hooksecurefunc(viewer, "Layout", function()
        SyncViewerToColumn()
        self:QueueReanchor()
    end)

    if viewer.RefreshLayout then
        hooksecurefunc(viewer, "RefreshLayout", function()
            SyncViewerToColumn()
            self:ReanchorCDMFrames()  -- immediate, not queued (prevent flash)
        end)
    end

    -- Hook SetPoint on the viewer to prevent Blizzard moving it
    hooksecurefunc(viewer, "SetPoint", function(_, _, relativeTo)
        if InCombatLockdown() then return end
        local col = self.actionColumn
        if not col or relativeTo == col then return end
        SyncViewerToColumn()
    end)

    -- Hook OnCooldownIDSet to detect frame recycling and spell transforms
    if CooldownViewerEssentialItemMixin
        and CooldownViewerEssentialItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerEssentialItemMixin, "OnCooldownIDSet", function(frame)
            -- Clear cached spell for this frame
            local fd = frameData[frame]
            if fd then fd.spellID = nil end
            self:QueueReanchor()
        end)
    end

    -- Hook pool acquire for new frames
    if viewer.itemFramePool and viewer.itemFramePool.Acquire then
        hooksecurefunc(viewer.itemFramePool, "Acquire", function()
            self:QueueReanchor()
        end)
    end

    -- OnUpdate frame for throttled reanchor
    local reanchorFrame = CreateFrame("Frame", "HUCDM_ReanchorFrame")
    reanchorFrame:Hide()
    reanchorFrame:SetScript("OnUpdate", function(f)
        if not reanchorDirty then f:Hide(); return end
        local now = GetTime()
        if now - lastReanchorTime < REANCHOR_THROTTLE then return end
        reanchorDirty = false
        lastReanchorTime = now
        f:Hide()
        self:ReanchorCDMFrames()
    end)
    self.reanchorFrame = reanchorFrame

    -- Initial sync
    SyncViewerToColumn()
end

----------------------------------------------------------------------
-- Queue a throttled reanchor
----------------------------------------------------------------------
function HUCDM:QueueReanchor()
    reanchorDirty = true
    if self.reanchorFrame then self.reanchorFrame:Show() end
end

----------------------------------------------------------------------
-- Reanchor all CDM Essential frames into our vertical slots
----------------------------------------------------------------------
function HUCDM:ReanchorCDMFrames()
    local viewer = _G["EssentialCooldownViewer"]
    if not viewer or not viewer.itemFramePool then return end
    if not self.cdmSpellSlots then return end

    local iconSize = 48
    local settings = self.db.profile.layout.columns.actions
    local scale = (settings and settings.scale) or 1
    local alpha = (settings and settings.alpha) or 1

    -- Reset flags before scanning
    for _, row in ipairs(self.actionRows or {}) do
        row.hasCDMFrame = false
    end

    for frame in viewer.itemFramePool:EnumerateActive() do
        local overrideID, baseID = GetCDMFrameSpellIDs(frame)
        local spellID = overrideID or baseID
        if spellID then
            local slot = self.cdmSpellSlots[spellID]
                or (baseID and self.cdmSpellSlots[baseID])
            if slot then
                -- Position frame at our row anchor and apply scale
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", slot.row, "TOPLEFT", 0, 0)
                frame:SetSize(iconSize, iconSize)
                frame:SetScale(scale)
                frame:SetAlpha(alpha)

                -- Store the canonical anchor so SetPoint hook can enforce it
                local fd = frameData[frame]
                if not fd then fd = {}; frameData[frame] = fd end
                fd.spellID = spellID
                fd.anchor = { "TOPLEFT", slot.row, "TOPLEFT", 0, 0 }

                -- Install per-frame SetPoint hook (once)
                if not fd.hooked then
                    fd.hooked = true
                    hooksecurefunc(frame, "SetPoint", function(_, _, relativeTo)
                        local d = frameData[frame]
                        if not d or not d.anchor then return end
                        -- If Blizzard moved us away from our anchor, force back
                        if relativeTo ~= d.anchor[2] then
                            frame:ClearAllPoints()
                            frame:SetPoint(
                                d.anchor[1], d.anchor[2], d.anchor[3],
                                d.anchor[4], d.anchor[5]
                            )
                        end
                    end)
                end

                frame:Show()
                slot.row.hasCDMFrame = true
            end
        end
    end

    -- Collapse rows with no CDM frame and re-layout
    self:RelayoutRows()

    -- Sync resource bar and buff bar heights to match action column
    if self.actionColumn and self.resourceBar then
        local h = self.actionColumn:GetHeight()
        self.resourceBar:SetHeight(h)
        if self.resourceColumn then self.resourceColumn:SetHeight(h) end
    end
    if self.actionColumn and self.buffBarColumn then
        local h = self.actionColumn:GetHeight()
        self.buffBarColumn:SetHeight(h)
        for _, bar in ipairs(self.buffBarFrames or {}) do
            bar:SetHeight(h)
            if bar.bar then
                local barIconSize = bar:GetWidth()
                bar.bar:SetHeight(h - barIconSize - 2)
            end
        end
    end
end

----------------------------------------------------------------------
-- Re-layout rows: hide empty rows, compact visible ones
----------------------------------------------------------------------
function HUCDM:RelayoutRows()
    if not self.actionRows or not self.actionColumn then return end

    local iconSize = 48
    local settings = self.db.profile.layout.columns.actions
    local spacing = settings.spacing
    local yPos = 0
    local visibleCount = 0

    for _, row in ipairs(self.actionRows) do
        if row.hasCDMFrame then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.actionColumn, "TOPLEFT", 0, -yPos)
            row:Show()
            yPos = yPos + iconSize + spacing
            visibleCount = visibleCount + 1
        else
            row:Hide()
        end
    end

    -- Resize column to fit only visible rows
    local totalHeight = 0
    if visibleCount > 0 then
        totalHeight = (visibleCount * iconSize) + ((visibleCount - 1) * spacing)
    end
    self.actionColumn:SetSize(iconSize, totalHeight)
end

----------------------------------------------------------------------
-- Restore CDM frames (remove our position overrides)
----------------------------------------------------------------------
function HUCDM:RestoreButtons()
    -- Clear our stored anchors so SetPoint hooks become no-ops
    for _, fd in pairs(frameData) do
        fd.anchor = nil
        fd.spellID = nil
    end

    -- Let Blizzard re-layout
    local viewer = _G["EssentialCooldownViewer"]
    if viewer and viewer.Layout then
        pcall(viewer.Layout, viewer)
    end
end

----------------------------------------------------------------------
-- Teardown
----------------------------------------------------------------------
function HUCDM:DestroyActionColumn()
    self:RestoreButtons()
    if self.reanchorFrame then
        self.reanchorFrame:Hide()
    end
    if self.actionColumn then
        self.actionColumn:Hide()
        self.actionColumn = nil
    end
    self.actionRows = {}
    self.cdmSpellSlots = {}
    -- Note: cdmHooksInstalled stays true — hooks are permanent (hooksecurefunc)
end

----------------------------------------------------------------------
-- Re-scan (called on events)
----------------------------------------------------------------------
function HUCDM:RescanActionButtons()
    self:ReanchorCDMFrames()
end

----------------------------------------------------------------------
-- Rotation assist glow: use WoW 12.0 C_AssistedCombat API + LibCustomGlow
----------------------------------------------------------------------
local LCG = LibStub("LibCustomGlow-1.0")
local GLOW_KEY = "HUCDM_Rotation"
local glowedFrames = {}

local function StartGlow(frame, styleIdx, r, g, b, opts)
    local color = { r, g, b, 1 }
    opts = opts or {}
    local speed = opts.speed or 1.0
    local thickness = opts.thickness or 2
    local scale = opts.scale or 1.0
    local numLines = opts.numLines or 8

    if styleIdx == 1 then
        LCG.ProcGlow_Start(frame, {
            color = color, key = GLOW_KEY, startAnim = true,
            duration = 1.0 / speed,
        })
    elseif styleIdx == 2 then
        LCG.ButtonGlow_Start(frame, color, speed)
    elseif styleIdx == 3 then
        LCG.PixelGlow_Start(
            frame, color, numLines, speed * 0.25, nil, thickness,
            nil, nil, nil, GLOW_KEY
        )
    elseif styleIdx == 4 then
        LCG.AutoCastGlow_Start(
            frame, color, numLines, speed, scale,
            nil, nil, GLOW_KEY
        )
    end
end

local function StopGlow(frame, styleIdx)
    if styleIdx == 1 then
        LCG.ProcGlow_Stop(frame, GLOW_KEY)
    elseif styleIdx == 2 then
        LCG.ButtonGlow_Stop(frame)
    elseif styleIdx == 3 then
        LCG.PixelGlow_Stop(frame, GLOW_KEY)
    elseif styleIdx == 4 then
        LCG.AutoCastGlow_Stop(frame, GLOW_KEY)
    end
end

local function UpdateRotationHighlights()
    local self = _G.HeadsUpCDM
    if not self.cdmSpellSlots then return end

    local glowStyle = self.db and self.db.profile.visuals.glowStyle or 1
    local gc = self.db and self.db.profile.visuals.glowColor or { 1, 0.84, 0 }

    -- Get the current suggested spell from the rotation helper
    local suggestedSpell = C_AssistedCombat and C_AssistedCombat.GetNextCastSpell
        and C_AssistedCombat.GetNextCastSpell()

    -- Clear all current glows
    for frame, oldStyle in pairs(glowedFrames) do
        StopGlow(frame, oldStyle)
    end
    wipe(glowedFrames)

    if not suggestedSpell then return end

    local viewer = _G["EssentialCooldownViewer"]
    if not viewer or not viewer.itemFramePool then return end

    local suggestedBase = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(suggestedSpell)

    for frame in viewer.itemFramePool:EnumerateActive() do
        local fd = frameData[frame]
        if fd and fd.spellID then
            local matched = (fd.spellID == suggestedSpell)
                or (suggestedBase and fd.spellID == suggestedBase)

            if not matched and frame.cooldownID then
                local ok, info = pcall(
                    C_CooldownViewer.GetCooldownViewerCooldownInfo, frame.cooldownID)
                if ok and info then
                    matched = (info.spellID == suggestedSpell)
                        or (info.overrideSpellID == suggestedSpell)
                        or (suggestedBase and info.spellID == suggestedBase)
                        or (suggestedBase and info.overrideSpellID == suggestedBase)
                end
            end

            if matched then
                local glowOpts = {
                    speed = self.db and self.db.profile.visuals.glowSpeed or 1.0,
                    thickness = self.db and self.db.profile.visuals.glowThickness or 2,
                    scale = self.db and self.db.profile.visuals.glowScale or 1.0,
                    numLines = self.db and self.db.profile.visuals.glowLines or 8,
                }
                StartGlow(frame, glowStyle, gc[1], gc[2], gc[3], glowOpts)
                glowedFrames[frame] = glowStyle
            end
        end
    end
end

function HUCDM:SetupRotationGlow()
    if self.glowEventsInstalled then return end
    self.glowEventsInstalled = true

    -- Expose for live settings changes
    self.UpdateRotationHighlights = UpdateRotationHighlights

    -- WoW 12.0: EventRegistry callback for rotation helper changes
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback(
            "AssistedCombatManager.OnAssistedHighlightSpellChange",
            UpdateRotationHighlights,
            "HUCDM_RotationGlow"
        )
    end

    -- Fallback: hook the manager's update method
    if AssistedCombatManager and AssistedCombatManager.UpdateAllAssistedHighlightFramesForSpell then
        hooksecurefunc(AssistedCombatManager, "UpdateAllAssistedHighlightFramesForSpell",
            UpdateRotationHighlights)
    end

    -- Poll initial state on next frame
    C_Timer.After(0, UpdateRotationHighlights)
end
