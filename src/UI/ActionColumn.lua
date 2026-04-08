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
local function GetCDMFrameSpellID(frame)
    if not frame or not frame.cooldownID then return nil end
    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, frame.cooldownID)
    if not ok or not info then return nil end
    return info.overrideSpellID or info.spellID
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

    for frame in viewer.itemFramePool:EnumerateActive() do
        local spellID = GetCDMFrameSpellID(frame)
        if spellID then
            local slot = self.cdmSpellSlots[spellID]
            if slot then
                -- Position frame at our row anchor
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", slot.row, "TOPLEFT", 0, 0)
                frame:SetSize(iconSize, iconSize)

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
            end
        end
    end
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
-- Rotation assist glow: use WoW 12.0 C_AssistedCombat API
-- Fires when the rotation helper suggestion changes
----------------------------------------------------------------------
local GLOW_BORDER = 4
local GLOW_BLOOM = 10
local glowFrames = setmetatable({}, { __mode = "k" })
local glowedFrames = {}

local function GetOrCreateGlow(parent)
    if glowFrames[parent] then return glowFrames[parent] end

    local glow = CreateFrame("Frame", nil, parent)
    glow:SetFrameLevel(parent:GetFrameLevel() + 5)
    glow:SetPoint("TOPLEFT", parent, "TOPLEFT", -GLOW_BLOOM, GLOW_BLOOM)
    glow:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", GLOW_BLOOM, -GLOW_BLOOM)

    -- Outer bloom/glow (soft, wide)
    local bloom = glow:CreateTexture(nil, "BACKGROUND")
    bloom:SetAllPoints()
    bloom:SetColorTexture(1, 0.84, 0, 0.35)
    bloom:SetBlendMode("ADD")

    -- Inner solid border (bright, sharp)
    local inner = CreateFrame("Frame", nil, glow)
    inner:SetPoint("TOPLEFT", glow, "TOPLEFT",
        GLOW_BLOOM - GLOW_BORDER, -(GLOW_BLOOM - GLOW_BORDER))
    inner:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT",
        -(GLOW_BLOOM - GLOW_BORDER), GLOW_BLOOM - GLOW_BORDER)

    local dirs = {
        { "TOPLEFT", "TOPRIGHT", 0, 0, 0, -GLOW_BORDER },
        { "BOTTOMLEFT", "BOTTOMRIGHT", 0, GLOW_BORDER, 0, 0 },
        { "TOPLEFT", "BOTTOMLEFT", 0, 0, GLOW_BORDER, 0 },
        { "TOPRIGHT", "BOTTOMRIGHT", -GLOW_BORDER, 0, 0, 0 },
    }
    for i = 1, #dirs do
        local d = dirs[i]
        local tex = inner:CreateTexture(nil, "OVERLAY")
        tex:SetPoint(d[1], inner, d[1], d[3], d[4])
        tex:SetPoint(d[2], inner, d[2], d[5], d[6])
        tex:SetColorTexture(1, 0.84, 0, 1)
    end

    -- Pulse animation on the bloom
    local ag = bloom:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local pulse = ag:CreateAnimation("Alpha")
    pulse:SetFromAlpha(0.35)
    pulse:SetToAlpha(0.65)
    pulse:SetDuration(0.5)
    pulse:SetSmoothing("IN_OUT")
    glow.pulseAnim = ag

    glow:Hide()
    glowFrames[parent] = glow
    return glow
end

local function UpdateRotationHighlights()
    local self = _G.HeadsUpCDM
    if not self.cdmSpellSlots then return end

    -- Get the current suggested spell from the rotation helper
    local suggestedSpell = C_AssistedCombat and C_AssistedCombat.GetNextCastSpell
        and C_AssistedCombat.GetNextCastSpell()

    -- Clear all current glows
    for frame in pairs(glowedFrames) do
        local glow = glowFrames[frame]
        if glow then
            if glow.pulseAnim then glow.pulseAnim:Stop() end
            glow:Hide()
        end
    end
    wipe(glowedFrames)

    if not suggestedSpell then return end

    -- Find CDM frame(s) matching the suggested spell
    local viewer = _G["EssentialCooldownViewer"]
    if not viewer or not viewer.itemFramePool then return end

    -- Also resolve the base spell of the suggestion for matching
    local suggestedBase = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(suggestedSpell)

    for frame in viewer.itemFramePool:EnumerateActive() do
        local fd = frameData[frame]
        if fd and fd.spellID then
            -- Match against: exact spellID, base spell, or CDM's full info
            local matched = (fd.spellID == suggestedSpell)
                or (suggestedBase and fd.spellID == suggestedBase)

            -- Also check CDM info for both spellID and overrideSpellID
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
                local glow = GetOrCreateGlow(frame)
                glow:Show()
                if glow.pulseAnim then glow.pulseAnim:Play() end
                glowedFrames[frame] = true
            end
        end
    end
end

function HUCDM:SetupRotationGlow()
    if self.glowEventsInstalled then return end
    self.glowEventsInstalled = true

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

    -- Also listen for SPELL_ACTIVATION_OVERLAY events (still fires for some procs)
    local glowEventFrame = CreateFrame("Frame", "HUCDM_GlowEvents", UIParent)
    glowEventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    glowEventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    glowEventFrame:SetScript("OnEvent", function()
        UpdateRotationHighlights()
    end)

    -- Poll initial state after a short delay
    C_Timer.After(0, UpdateRotationHighlights)
end
