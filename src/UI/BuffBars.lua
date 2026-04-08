-- HeadsUpCDM: Reposition Blizzard CDM Buff Bar frames into a vertical column.
-- Uses the same hook-and-reanchor pattern as ActionColumn and BuffIcons.

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
-- Build the buff bars column with mapping from preset
----------------------------------------------------------------------
function HUCDM:CreateBuffBars(preset, totalHeight)
    local layout = self.layoutFrame
    if not layout then return end

    local barWidth = 18
    local barGap = 3
    local buffBarConfig = preset.buffBarDefaults or {}

    -- Container column
    local column = CreateFrame("Frame", "HUCDM_BuffBarsColumn", layout)
    local columnWidth = (#buffBarConfig * barWidth) + ((#buffBarConfig - 1) * barGap)
    if columnWidth <= 0 then columnWidth = 1 end
    column:SetSize(columnWidth, totalHeight)
    column:Show()

    self.buffBarColumn = column
    self.buffBarSpellSlots = {}  -- spellID -> { xOffset }
    self.buffBarFrames = {}

    for i, buffInfo in ipairs(buffBarConfig) do
        local xOffset = (i - 1) * (barWidth + barGap)
        self.buffBarSpellSlots[buffInfo.id] = {
            xOffset = xOffset,
            barWidth = barWidth,
            totalHeight = totalHeight,
            buffInfo = buffInfo,
        }
    end

    -- Hook the buff bar viewer
    self:SetupBuffBarHooks()
    C_Timer.After(1, function() self:ReanchorBuffBars() end)
    C_Timer.After(3, function() self:ReanchorBuffBars() end)

    self:RegisterColumn("buffBars", column)
    return column
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

    -- Throttle frame
    local reanchorFrame = CreateFrame("Frame", "HUCDM_BuffBarReanchor")
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
-- Reanchor buff bar frames into our vertical column
----------------------------------------------------------------------
function HUCDM:ReanchorBuffBars()
    local viewer = _G["BuffBarCooldownViewer"]
    if not viewer or not viewer.itemFramePool then return end
    if not self.buffBarSpellSlots or not self.buffBarColumn then return end

    for frame in viewer.itemFramePool:EnumerateActive() do
        local spellID = GetBarFrameSpellID(frame)
        if spellID then
            local slot = self.buffBarSpellSlots[spellID]
            if slot then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", self.buffBarColumn, "TOPLEFT", slot.xOffset, 0)
                frame:SetSize(slot.barWidth, slot.totalHeight)
                frame:Show()

                local fd = barFrameData[frame]
                if not fd then fd = {}; barFrameData[frame] = fd end
                fd.spellID = spellID
                fd.anchor = { "TOPLEFT", self.buffBarColumn, "TOPLEFT", slot.xOffset, 0 }

                if not fd.hooked then
                    fd.hooked = true
                    hooksecurefunc(frame, "SetPoint", function(_, _, relativeTo)
                        local d = barFrameData[frame]
                        if not d or not d.anchor then return end
                        if relativeTo ~= d.anchor[2] then
                            frame:ClearAllPoints()
                            frame:SetPoint(
                                d.anchor[1], d.anchor[2], d.anchor[3],
                                d.anchor[4], d.anchor[5]
                            )
                        end
                    end)
                end
            end
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
