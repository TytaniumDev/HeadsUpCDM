-- HeadsUpCDM: Reposition Blizzard CDM Buff Icon frames next to their paired action spells.
-- Uses the same hook-and-reanchor pattern as ActionColumn — no custom frames.

local HUCDM = _G.HeadsUpCDM

-- Per-frame data (weak-keyed)
local buffFrameData = setmetatable({}, { __mode = "k" })

----------------------------------------------------------------------
-- Resolve the spellID for a CDM buff frame
----------------------------------------------------------------------
local function GetBuffFrameSpellIDs(frame)
    if not frame or not frame.cooldownID then return nil, nil end
    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, frame.cooldownID)
    if not ok or not info then return nil, nil end
    return info.overrideSpellID, info.spellID
end

----------------------------------------------------------------------
-- Build the buff-to-action mapping from preset
----------------------------------------------------------------------
function HUCDM:CreateBuffIcons(preset)
    self.buffSpellToRow = {}   -- buffSpellID -> { row, buffIndex }
    self.buffIconFrames = {}

    local iconSize = 48
    local iconGap = 4

    for rowIdx, row in ipairs(self.actionRows or {}) do
        local spellInfo = preset.spells[rowIdx]
        if spellInfo and spellInfo.pairedBuffs then
            for buffIdx, buffInfo in ipairs(spellInfo.pairedBuffs) do
                local xOffset = iconSize + ((buffIdx - 1) * (iconSize + iconGap)) + iconGap
                self.buffSpellToRow[buffInfo.id] = {
                    row = row,
                    xOffset = xOffset,
                    buffInfo = buffInfo,
                }
            end
        end
    end

    -- Hook the buff icon viewer
    self:SetupBuffIconHooks()
    C_Timer.After(0, function() self:ReanchorBuffIcons() end)
end

----------------------------------------------------------------------
-- Hook the BuffIconCooldownViewer
----------------------------------------------------------------------
function HUCDM:SetupBuffIconHooks()
    if self.buffIconHooksInstalled then return end

    local viewer = _G["BuffIconCooldownViewer"]
    if not viewer then return end

    self.buffIconHooksInstalled = true

    -- Hook OnCooldownIDSet on buff icon mixin
    if CooldownViewerBuffIconItemMixin
        and CooldownViewerBuffIconItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnCooldownIDSet", function(frame)
            local fd = buffFrameData[frame]
            if fd then fd.spellID = nil end
            self:QueueBuffIconReanchor()
        end)
    end

    -- Hook pool acquire
    if viewer.itemFramePool and viewer.itemFramePool.Acquire then
        hooksecurefunc(viewer.itemFramePool, "Acquire", function()
            self:QueueBuffIconReanchor()
        end)
    end

    -- Hook Layout
    if viewer.Layout then
        hooksecurefunc(viewer, "Layout", function()
            self:QueueBuffIconReanchor()
        end)
    end
    if viewer.RefreshLayout then
        hooksecurefunc(viewer, "RefreshLayout", function()
            self:ReanchorBuffIcons()
        end)
    end

    -- Throttle frame
    local reanchorFrame = CreateFrame("Frame", "HUCDM_BuffIconReanchor")
    reanchorFrame:Hide()
    self.buffIconReanchorDirty = false
    reanchorFrame:SetScript("OnUpdate", function(f)
        if not self.buffIconReanchorDirty then f:Hide(); return end
        self.buffIconReanchorDirty = false
        f:Hide()
        self:ReanchorBuffIcons()
    end)
    self.buffIconReanchorFrame = reanchorFrame
end

function HUCDM:QueueBuffIconReanchor()
    self.buffIconReanchorDirty = true
    if self.buffIconReanchorFrame then self.buffIconReanchorFrame:Show() end
end

----------------------------------------------------------------------
-- Reanchor buff icon frames to their paired action row
----------------------------------------------------------------------
function HUCDM:ReanchorBuffIcons()
    local viewer = _G["BuffIconCooldownViewer"]
    if not viewer or not viewer.itemFramePool then return end
    if not self.buffSpellToRow then return end

    local iconSize = 48
    local settings = self.db.profile.layout.columns.actions
    local alpha = (settings and settings.alpha) or 1

    for frame in viewer.itemFramePool:EnumerateActive() do
        local overrideID, baseID = GetBuffFrameSpellIDs(frame)
        local spellID = overrideID or baseID
        if spellID then
            local slot = (overrideID and self.buffSpellToRow[overrideID])
                or (baseID and self.buffSpellToRow[baseID])
            if slot then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", slot.row, "TOPLEFT", slot.xOffset, 0)
                frame:SetSize(iconSize, iconSize)
                frame:SetAlpha(alpha)
                -- Do NOT call Show() here — Blizzard's CDM manages visibility
                -- based on actual buff state. Forcing Show would display inactive buffs.

                -- Store anchor and install SetPoint hook
                local fd = buffFrameData[frame]
                if not fd then fd = {}; buffFrameData[frame] = fd end
                fd.spellID = spellID
                fd.anchor = { "TOPLEFT", slot.row, "TOPLEFT", slot.xOffset, 0 }

                if not fd.hooked then
                    fd.hooked = true
                    hooksecurefunc(frame, "SetPoint", function(_, _, relativeTo)
                        local d = buffFrameData[frame]
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
-- Update (called by ticker — now minimal since Blizzard manages state)
----------------------------------------------------------------------
function HUCDM:UpdateBuffIcons()
    -- Blizzard CDM handles buff state display; we just need to reanchor
    self:ReanchorBuffIcons()
end

----------------------------------------------------------------------
-- Teardown
----------------------------------------------------------------------
function HUCDM:DestroyBuffIcons()
    -- Clear stored anchors so SetPoint hooks become no-ops
    for _, fd in pairs(buffFrameData) do
        fd.anchor = nil
        fd.spellID = nil
    end
    if self.buffIconReanchorFrame then
        self.buffIconReanchorFrame:Hide()
    end
    self.buffSpellToRow = {}
    self.buffIconFrames = {}
end

----------------------------------------------------------------------
-- Event registration (kept for compatibility with Core.lua calls)
----------------------------------------------------------------------
function HUCDM:RegisterBuffIconEvents()
    -- No longer needed — CDM hooks handle everything
end
