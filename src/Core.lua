-- HeadsUpCDM: Addon lifecycle, slash commands, event handlers, display orchestration

local HUCDM = _G.HeadsUpCDM

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------
function HUCDM:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("HeadsUpCDMDB", self.defaults, true)
    self:RegisterChatCommand("headsupcdm", "SlashCommand")
    self:RegisterChatCommand("hucdm", "SlashCommand")
    self:RegisterChatCommand("cdm", "OpenBlizzardCDM")
    self:SetupOptions()
end

function HUCDM:OnEnable()
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "OnSpecChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatDrop")
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "OnActionBarChanged")
    self:RegisterEvent("ACTIONBAR_PAGE_CHANGED", "OnActionBarChanged")

    -- Build on next frame (let Blizzard finish its current layout pass)
    C_Timer.After(0, function()
        self:BuildDisplay()
    end)

    self:Print("HeadsUpCDM loaded. Type /hucdm for options.")
end

----------------------------------------------------------------------
-- Build / Rebuild / Teardown display
----------------------------------------------------------------------
function HUCDM:BuildDisplay()
    if not self.db.profile.enabled then return end

    -- Detect spec and build
    local presetKey = self:DetectCurrentBuild()
    if not presetKey then
        self:Print("HeadsUpCDM: Unsupported spec")
        self:TeardownDisplay()
        return
    end

    local preset = self.SpellData.presets[presetKey]
    if not preset then return end

    self.currentPresetKey = presetKey
    self.currentPreset = preset

    -- Create layout frame
    self:CreateLayout()

    -- Calculate total height for resource and buff bar columns
    local settings = self.db.profile.layout.columns.actions
    local spellCount = #preset.spells
    local iconSize = 48
    local totalHeight = (spellCount * iconSize) + ((spellCount - 1) * settings.spacing)

    -- Build columns
    self:CreateActionColumn(preset)
    self:SetupRotationGlow()
    self:CreateResourceBar(totalHeight)
    self:CreateBuffIcons(preset)
    self:CreateBuffBars(preset, totalHeight)

    -- Arrange columns
    self:ArrangeColumns()

    -- Initial updates
    self:UpdateResourceBar()
    self:UpdateBuffIcons()
    self:UpdateBuffBars()
end

function HUCDM:TeardownDisplay()
    self:DestroyBuffBars()
    self:DestroyBuffIcons()
    self:DestroyResourceBar()
    self:DestroyActionColumn()
    self:DestroyLayout()
    self.currentPreset = nil
    self.currentPresetKey = nil
end

function HUCDM:RebuildDisplay()
    self:TeardownDisplay()
    self:BuildDisplay()
end

----------------------------------------------------------------------
-- Event handlers
----------------------------------------------------------------------
function HUCDM:OnSpecChanged()
    self:RebuildDisplay()
end

function HUCDM:OnCombatDrop()
    -- Apply any queued reparenting changes that couldn't happen in combat
    if self.pendingRescan then
        self.pendingRescan = false
        self:RescanActionButtons()
    end
    self:FlushPendingActionBarRestore()
end

function HUCDM:OnActionBarChanged()
    if InCombatLockdown() then
        self.pendingRescan = true
    else
        if self.actionBarUpdateTimer then
            self.actionBarUpdateTimer:Cancel()
        end
        self.actionBarUpdateTimer = C_Timer.NewTimer(0.2, function()
            self:RescanActionButtons()
            self.actionBarUpdateTimer = nil
        end)
    end
end

----------------------------------------------------------------------
-- Blizzard CDM settings shortcut
----------------------------------------------------------------------
function HUCDM:OpenBlizzardCDM()
    local frame = CooldownViewerSettings
    if not frame then
        self:Print("Blizzard Cooldown Manager settings not available.")
        return
    end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
function HUCDM:SlashCommand(input)
    local cmd = strtrim(input or "")
    if cmd == "" then
        -- Open options panel
        LibStub("AceConfigDialog-3.0"):Open("HeadsUpCDM")
    elseif cmd == "toggle" then
        self:Toggle()
    elseif cmd == "lock" then
        self:Lock()
    elseif cmd == "unlock" then
        self:Unlock()
    elseif cmd == "reset" then
        self:ResetPosition()
    elseif cmd == "debug" then
        self:DebugCDMFrames()
        if self.layoutFrame then
            self.layoutFrame:ClearAllPoints()
            local pos = self.db.profile.position
            self.layoutFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        end
    else
        self:Print("Usage: /hucdm [toggle|lock|unlock|reset]")
    end
end

function HUCDM:Toggle()
    self.db.profile.enabled = not self.db.profile.enabled
    if self.db.profile.enabled then
        self:BuildDisplay()
        self:Print("Enabled")
    else
        self:TeardownDisplay()
        self:Print("Disabled")
    end
end

function HUCDM:Lock()
    self.db.profile.locked = true
    self:UpdateDragBehavior()
    self:UpdateBuffIcons()
    self:Print("Display locked.")
end

function HUCDM:Unlock()
    self.db.profile.locked = false
    self:UpdateDragBehavior()
    self:UpdateBuffIcons()
    self:Print("Display unlocked. Drag to reposition.")
end

function HUCDM:ResetPosition()
    self.db.profile.position = { point = "CENTER", x = 0, y = 200 }
    self:Print("Position reset to default.")
end

function HUCDM:DebugCDMFrames()
    local viewer = _G["EssentialCooldownViewer"]
    if not viewer or not viewer.itemFramePool then
        self:Print("EssentialCooldownViewer not found")
        return
    end
    self:Print("--- Essential CDM Frames ---")
    for frame in viewer.itemFramePool:EnumerateActive() do
        local cdID = frame.cooldownID
        local info = cdID and C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
        if info then
            local name = C_Spell.GetSpellName(info.spellID) or "?"
            self:Print(string.format("cdID=%s spell=%s override=%s name=%s",
                tostring(cdID), tostring(info.spellID),
                tostring(info.overrideSpellID), name))
        else
            self:Print("cdID=" .. tostring(cdID) .. " (no info)")
        end
    end
    self:Print("--- Our preset spells ---")
    if self.currentPreset then
        for _, s in ipairs(self.currentPreset.spells) do
            self:Print(string.format("id=%d name=%s", s.id, s.name))
        end
    end

    self:Print("--- BuffIcon CDM Frames ---")
    local buffViewer = _G["BuffIconCooldownViewer"]
    if buffViewer and buffViewer.itemFramePool then
        local count = 0
        for frame in buffViewer.itemFramePool:EnumerateActive() do
            count = count + 1
            local cdID = frame.cooldownID
            local info = cdID and C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
            if info then
                local name = C_Spell.GetSpellName(info.spellID) or "?"
                self:Print(string.format("  cdID=%s spell=%s override=%s name=%s",
                    tostring(cdID), tostring(info.spellID),
                    tostring(info.overrideSpellID), name))
            end
        end
        self:Print("  Total active buff frames: " .. count)
    else
        self:Print("  BuffIconCooldownViewer not found")
    end

    self:Print("--- Our paired buff IDs ---")
    if self.buffSpellToRow then
        for buffID, slot in pairs(self.buffSpellToRow) do
            self:Print(string.format("  id=%d name=%s", buffID, slot.buffInfo.name))
        end
    end
end
