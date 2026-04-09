-- HeadsUpCDM: Vertical buff duration bars using custom StatusBars.
-- Blizzard CDM buff bar frames are hidden off-screen; their Bar values
-- are mirrored to addon-created StatusBars so we control size/orientation.
-- (Repositioning Blizzard BuffBarCooldownViewer items directly doesn't work
-- because the viewer's layout system overrides SetSize on every frame.)

local HUCDM = _G.HeadsUpCDM

-- Per-frame data (weak-keyed)
local barFrameData = setmetatable({}, { __mode = "k" })

----------------------------------------------------------------------
-- Resolve the spellID for a CDM buff bar frame
----------------------------------------------------------------------
local function GetBarFrameSpellID(frame)
    if not frame or not frame.cooldownID then return nil end
    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, frame.cooldownID)
    if not ok or not info then return nil end
    return info.overrideSpellID or info.spellID
end

----------------------------------------------------------------------
-- File-level sync helper (avoids closure creation per pcall call)
----------------------------------------------------------------------
local function SyncSlotValues(slot)
    local mn, mx = slot.blizzBar:GetMinMaxValues()
    local val = slot.blizzBar:GetValue()
    slot.customBar:SetMinMaxValues(mn, mx)
    slot.customBar:SetValue(val)
end

----------------------------------------------------------------------
-- Build the buff bars column with custom StatusBars per preset slot
----------------------------------------------------------------------
function HUCDM:CreateBuffBars(preset, totalHeight)
    local layout = self.layoutFrame
    if not layout then return end

    local barWidth = 18
    local barGap = 3
    local iconSize = barWidth
    local buffBarConfig = preset.buffBarDefaults or {}

    -- Container column
    local column = CreateFrame("Frame", nil, layout)
    local columnWidth = (#buffBarConfig * barWidth) + ((#buffBarConfig - 1) * barGap)
    if columnWidth <= 0 then columnWidth = 1 end
    column:SetSize(columnWidth, totalHeight)
    column:Show()

    self.buffBarColumn = column
    self.buffBarSpellSlots = {}
    self.buffBarFrames = {}

    for i, buffInfo in ipairs(buffBarConfig) do
        local xOffset = (i - 1) * (barWidth + barGap)

        -- Custom vertical StatusBar — two-point anchored so it auto-resizes
        -- with the column. Spans from column top to iconSize above column bottom.
        local bar = CreateFrame("StatusBar", nil, column)
        bar:SetPoint("TOPLEFT", column, "TOPLEFT", xOffset, 0)
        bar:SetPoint("BOTTOMRIGHT", column, "BOTTOMLEFT", xOffset + barWidth, iconSize)
        bar:SetOrientation("VERTICAL")
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")

        local c = buffInfo.color
        bar:SetStatusBarColor(c[1], c[2], c[3])

        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.6)

        -- Own icon texture at the bottom of the column
        local icon = column:CreateTexture(nil, "ARTWORK")
        icon:SetSize(barWidth, barWidth)
        icon:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", xOffset, 0)
        icon:Hide()

        bar:Hide()

        self.buffBarSpellSlots[buffInfo.id] = {
            xOffset = xOffset,
            barWidth = barWidth,
            iconSize = iconSize,
            buffInfo = buffInfo,
            customBar = bar,
            customIcon = icon,
            blizzBar = nil,
            active = false,
        }
    end

    -- Reuse sync frame if it already exists (survives spec-change teardown)
    local syncFrame = self.buffBarSyncFrame or CreateFrame("Frame", nil)
    local syncElapsed = 0
    syncFrame:SetScript("OnUpdate", function(_, elapsed)
        syncElapsed = syncElapsed + elapsed
        if syncElapsed < 0.05 then return end
        syncElapsed = 0
        self:SyncBuffBarValues()
    end)
    syncFrame:Show()
    self.buffBarSyncFrame = syncFrame

    -- Hook the buff bar viewer
    self:SetupBuffBarHooks()
    C_Timer.After(0, function() self:ReanchorBuffBars() end)

    self:RegisterColumn("buffBars", column)
    return column
end

----------------------------------------------------------------------
-- Mirror Blizzard bar min/max/value to our custom bars
----------------------------------------------------------------------
function HUCDM:SyncBuffBarValues()
    if not self.buffBarSpellSlots then return end
    for _, slot in pairs(self.buffBarSpellSlots) do
        if slot.active and slot.blizzBar and slot.customBar then
            pcall(SyncSlotValues, slot)
        end
    end
end

----------------------------------------------------------------------
-- Sync all side-column heights with the action column
----------------------------------------------------------------------
function HUCDM:SyncColumnHeights()
    if not self.actionColumn then return end
    local h = self.actionColumn:GetHeight()
    if h <= 0 then return end
    -- Defer to next frame: this can be called from Blizzard's RefreshLayout
    -- hook chain, where the execution path is tainted and SetHeight on our
    -- own frames gets blocked by the 12.0 taint system.
    C_Timer.After(0, function()
        if self.buffBarColumn then self.buffBarColumn:SetHeight(h) end
        if self.resourceColumn then self.resourceColumn:SetHeight(h) end
        if self.resourceBar then self.resourceBar:SetHeight(h) end
    end)
end

----------------------------------------------------------------------
-- Hook the BuffBarCooldownViewer
----------------------------------------------------------------------
function HUCDM:SetupBuffBarHooks()
    if self.buffBarHooksInstalled then return end

    local viewer = _G["BuffBarCooldownViewer"]
    if not viewer then return end

    self.buffBarHooksInstalled = true

    -- Hook OnCooldownIDSet on buff bar mixin
    if CooldownViewerBuffBarItemMixin
        and CooldownViewerBuffBarItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerBuffBarItemMixin, "OnCooldownIDSet", function(frame)
            local fd = barFrameData[frame]
            if fd then fd.spellID = nil end
            self:QueueBuffBarReanchor()
        end)
    end

    -- Hook pool acquire
    if viewer.itemFramePool and viewer.itemFramePool.Acquire then
        hooksecurefunc(viewer.itemFramePool, "Acquire", function()
            self:QueueBuffBarReanchor()
        end)
    end

    -- Hook Layout
    if viewer.Layout then
        hooksecurefunc(viewer, "Layout", function()
            self:QueueBuffBarReanchor()
        end)
    end
    if viewer.RefreshLayout then
        hooksecurefunc(viewer, "RefreshLayout", function()
            self:ReanchorBuffBars()
        end)
    end

    -- Reuse throttle frame if it already exists
    local reanchorFrame = self.buffBarReanchorFrame or CreateFrame("Frame", nil)
    reanchorFrame:Hide()
    self.buffBarReanchorDirty = false
    reanchorFrame:SetScript("OnUpdate", function(f)
        if not self.buffBarReanchorDirty then f:Hide(); return end
        self.buffBarReanchorDirty = false
        f:Hide()
        self:ReanchorBuffBars()
    end)
    self.buffBarReanchorFrame = reanchorFrame
end

function HUCDM:QueueBuffBarReanchor()
    self.buffBarReanchorDirty = true
    if self.buffBarReanchorFrame then self.buffBarReanchorFrame:Show() end
end

----------------------------------------------------------------------
-- Reanchor: hide Blizzard frames, link their bars, show our visuals
----------------------------------------------------------------------
function HUCDM:ReanchorBuffBars()
    local viewer = _G["BuffBarCooldownViewer"]
    if not viewer or not viewer.itemFramePool then return end
    if not self.buffBarSpellSlots or not self.buffBarColumn then return end

    self:SyncColumnHeights()

    -- Reset active state
    for _, slot in pairs(self.buffBarSpellSlots) do
        slot.active = false
        slot.blizzBar = nil
    end

    for frame in viewer.itemFramePool:EnumerateActive() do
        local spellID = GetBarFrameSpellID(frame)
        if spellID then
            local slot = self.buffBarSpellSlots[spellID]
            if slot then
                slot.active = true
                slot.blizzBar = frame.Bar

                -- Move Blizzard frame off-screen (keep active for value updates)
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", UIParent, "CENTER", -10000, 0)
                frame:Show()

                local fd = barFrameData[frame]
                if not fd then fd = {}; barFrameData[frame] = fd end
                fd.spellID = spellID

                if not fd.hooked then
                    fd.hooked = true
                    hooksecurefunc(frame, "SetPoint", function(_, _, relativeTo)
                        if relativeTo ~= UIParent then
                            frame:ClearAllPoints()
                            frame:SetPoint("CENTER", UIParent, "CENTER", -10000, 0)
                        end
                    end)
                end

                -- Set icon texture from the spell ID
                local info = C_Spell.GetSpellInfo(spellID)
                if info and info.iconID then
                    slot.customIcon:SetTexture(info.iconID)
                end

                -- Show our custom bar and icon
                slot.customBar:Show()
                slot.customIcon:Show()
            end
        end
    end

    -- Hide custom bars/icons for inactive slots
    for _, slot in pairs(self.buffBarSpellSlots) do
        if not slot.active then
            slot.customBar:Hide()
            slot.customIcon:Hide()
        end
    end
end

----------------------------------------------------------------------
-- Update (compatibility with Core.lua calls)
----------------------------------------------------------------------
function HUCDM:UpdateBuffBars()
    self:ReanchorBuffBars()
end

----------------------------------------------------------------------
-- Teardown
----------------------------------------------------------------------
function HUCDM:DestroyBuffBars()
    for _, fd in pairs(barFrameData) do
        fd.anchor = nil
        fd.spellID = nil
    end
    if self.buffBarSyncFrame then
        self.buffBarSyncFrame:Hide()
    end
    if self.buffBarReanchorFrame then
        self.buffBarReanchorFrame:Hide()
    end
    if self.buffBarColumn then
        self.buffBarColumn:Hide()
        self.buffBarColumn = nil
    end
    self.buffBarSpellSlots = {}
    self.buffBarFrames = {}
end

----------------------------------------------------------------------
-- Event registration (kept for compatibility)
----------------------------------------------------------------------
function HUCDM:RegisterBuffBarEvents()
    -- No longer needed — CDM hooks handle everything
end
