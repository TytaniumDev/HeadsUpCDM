-- HeadsUpCDM: Reposition Blizzard CDM Essential Cooldown frames into a vertical layout.
-- Syncs the EssentialCooldownViewer to our column frame, then overrides individual
-- icon positions. Hooks SetPoint to enforce positions when Blizzard re-layouts.
-- Based on patterns from EllesmereUI's CDM reanchor system.

local HUCDM = _G.HeadsUpCDM

-- Bar number -> Blizzard button name prefix
local BAR_BUTTON_PREFIX = {
    [1] = "ActionButton",
    [2] = "MultiBarBottomLeftButton",
    [3] = "MultiBarBottomRightButton",
    [4] = "MultiBarRightButton",
    [5] = "MultiBarLeftButton",
    [6] = "MultiBar5Button",
    [7] = "MultiBar6Button",
    [8] = "MultiBar7Button",
}

function HUCDM:ResolveActionButton(bar, slot)
    local prefix = BAR_BUTTON_PREFIX[bar]
    if not prefix then return nil end
    return _G[prefix .. slot]
end

----------------------------------------------------------------------
-- SecureHandler for ActionButton reparenting — MUST be created at
-- file-load time (before PLAYER_LOGIN) to be "explicitly protected".
-- Runtime-created handlers cannot execute protected operations on
-- Blizzard ActionButtons. Matches EllesmereUI's pattern.
--
-- Uses indexed attributes: "btn-N" frame refs, "layout-N" position
-- strings. Trigger: SetAttribute("do-setup", GetTime()).
----------------------------------------------------------------------
local actionBarHandler = CreateFrame("Frame", "HUCDM_ActionBarHandler",
    UIParent, "SecureHandlerAttributeTemplate")

actionBarHandler:SetAttributeNoHandler("_onattributechanged", [=[
    if name == "do-setup" then
        local count = self:GetAttribute("btn-count") or 0
        local uip = self:GetFrameRef("uiParent")
        if not uip then return end
        for i = 1, count do
            local b = self:GetFrameRef("btn-" .. i)
            local layout = self:GetAttribute("layout-" .. i)
            if b and layout then
                local x, y, w, h = strsplit("|", layout)
                b:SetParent(uip)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", uip, "BOTTOMLEFT",
                    tonumber(x) or 0, tonumber(y) or 0)
                b:SetWidth(tonumber(w) or 48)
                b:SetHeight(tonumber(h) or 48)
                b:Show()
            end
        end
    elseif name == "do-restore" then
        local count = self:GetAttribute("btn-count") or 0
        for i = 1, count do
            local b = self:GetFrameRef("btn-" .. i)
            local p = self:GetFrameRef("orig-" .. i)
            if b and p then
                b:SetParent(p)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
                b:Show()
            end
        end
    end
]=])

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

    -- Set up ActionButtons for spells with source = "actionbar".
    -- Uses SecureHandler restricted code to call protected SetParent/SetPoint
    -- on Blizzard ActionButtons (required in WoW 12.0 due to taint).
    -- Falls back to static icon frames if the button global is missing.
    self.actionBarButtons = {}
    local alpha = (settings and settings.alpha) or 1

    for i, spellInfo in ipairs(preset.spells) do
        if spellInfo.source == "actionbar" then
            local row = self.actionRows[i]
            local btn = spellInfo.bar and spellInfo.slot
                and self:ResolveActionButton(spellInfo.bar, spellInfo.slot)

            if btn then
                -- Register button on the file-load-time SecureHandler.
                -- The handler is explicitly protected and can execute
                -- SetParent/SetPoint on Blizzard ActionButtons.
                -- Trigger is deferred to TriggerActionBarHandlers().
                --
                -- Note: HUD scale does NOT apply to action bar buttons.
                -- Scale interacts with SetPoint offsets in restricted code,
                -- causing position drift. Buttons stay at native size.
                local abIdx = #self.actionBarButtons + 1
                local origParent = btn:GetParent()
                actionBarHandler:SetFrameRef("btn-" .. abIdx, btn)
                actionBarHandler:SetFrameRef("orig-" .. abIdx, origParent)
                pcall(btn.SetAlpha, btn, alpha)

                row.hasActionBarButton = true

                self.actionBarButtons[#self.actionBarButtons + 1] = {
                    btn = btn,
                    row = row,
                    spellID = spellInfo.id,
                }
            else
                -- Fallback: static icon frame (button not found on bar)
                local icon = CreateFrame("Frame", nil, row)
                icon:SetAllPoints(row)
                local tex = icon:CreateTexture(nil, "ARTWORK")
                tex:SetAllPoints()
                local ok, info = pcall(C_Spell.GetSpellInfo, spellInfo.id)
                if ok and info and info.iconID then
                    pcall(tex.SetTexture, tex, info.iconID)
                end
                icon.texture = tex
                icon:SetAlpha(alpha)
                icon:Show()

                row.hasActionBarButton = true

                self.actionBarButtons[#self.actionBarButtons + 1] = {
                    icon = icon,
                    row = row,
                    spellID = spellInfo.id,
                }
            end
        end
    end

    -- Sync the CDM viewer to our column and install hooks
    self:SetupCDMHooks()

    -- Deferred initial positioning (next frame, after ArrangeColumns finalizes positions)
    C_Timer.After(0, function()
        self:TriggerActionBarHandlers()
        self:ReanchorCDMFrames()
    end)

    self:RegisterColumn("actions", column)
    return column
end

----------------------------------------------------------------------
-- Compute absolute positions and trigger SecureHandler reanchor
-- for ActionBar buttons. Must be called AFTER ArrangeColumns so
-- row frames have valid screen positions.
----------------------------------------------------------------------
function HUCDM:TriggerActionBarHandlers()
    local buttons = self.actionBarButtons
    if not buttons or #buttons == 0 then return end

    actionBarHandler:SetFrameRef("uiParent", UIParent)
    local count = 0
    for i, entry in ipairs(buttons) do
        if entry.btn and entry.row then
            local left = entry.row:GetLeft()
            local top = entry.row:GetTop()
            if left and top then
                count = count + 1
                actionBarHandler:SetAttribute("layout-" .. i,
                    string.format("%.1f|%.1f|48|48", left, top))
            end
        end
    end
    actionBarHandler:SetAttribute("btn-count", #buttons)

    if count > 0 then
        actionBarHandler:SetAttribute("do-setup", GetTime())
    end
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
    local alpha = (settings and settings.alpha) or 1

    -- Reset flags before scanning (preserve rows with action bar buttons as having content)
    for _, row in ipairs(self.actionRows or {}) do
        row.hasCDMFrame = row.hasActionBarButton or false
    end

    for frame in viewer.itemFramePool:EnumerateActive() do
        local overrideID, baseID = GetCDMFrameSpellIDs(frame)
        local spellID = overrideID or baseID
        if spellID then
            local slot = (overrideID and self.cdmSpellSlots[overrideID])
                or (baseID and self.cdmSpellSlots[baseID])
            if slot then
                -- Position frame at our row anchor
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", slot.row, "TOPLEFT", 0, 0)
                frame:SetSize(iconSize, iconSize)
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

    -- Update actionbar entry alpha
    for _, entry in ipairs(self.actionBarButtons or {}) do
        if entry.btn then
            pcall(entry.btn.SetAlpha, entry.btn, alpha)
        elseif entry.icon then
            entry.icon:SetAlpha(alpha)
        end
    end

    -- Collapse rows with no CDM frame and re-layout
    self:RelayoutRows()

    -- Sync resource bar and buff bar heights to match action column.
    -- Deferred: this runs from Blizzard hook chains where taint blocks SetHeight.
    -- Flag-based throttle: only one pending sync per frame to avoid closure pressure.
    if self.actionColumn and not self.heightSyncPending then
        self.heightSyncPending = true
        local h = self.actionColumn:GetHeight()
        C_Timer.After(0, function()
            self.heightSyncPending = false
            -- resourceBar tracks resourceColumn via two-point anchors — no SetHeight needed
            if self.resourceColumn then self.resourceColumn:SetHeight(h) end
            if self.buffBarColumn then
                self.buffBarColumn:SetHeight(h)
                for _, bar in ipairs(self.buffBarFrames or {}) do
                    bar:SetHeight(h)
                    if bar.bar then
                        local barIconSize = bar:GetWidth()
                        bar.bar:SetHeight(h - barIconSize - 2)
                    end
                end
            end
        end)
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
        if row.hasCDMFrame or row.hasActionBarButton then
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

    -- Restore SecureHandler buttons, hide fallback icons
    local hasHandlerEntries = false
    for _, entry in ipairs(self.actionBarButtons or {}) do
        if entry.btn then
            hasHandlerEntries = true
        elseif entry.icon then
            entry.icon:Hide()
        end
    end
    if hasHandlerEntries then
        actionBarHandler:SetAttribute("do-restore", GetTime())
    end
    self.actionBarButtons = {}

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
