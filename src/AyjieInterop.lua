-- HeadsUpCDM: Runtime interop with Ayije_CDM.
-- Patches Ayjie's viewer hooks so HeadsUpCDM owns Essential/Buff/BuffBar
-- while Ayjie keeps Utility, Defensives, Trinkets, Racials, CastBar, etc.

local HUCDM = _G.HeadsUpCDM

-- Viewer names HeadsUpCDM owns exclusively
local OWNED_VIEWERS = {
    ["EssentialCooldownViewer"] = true,
    ["BuffIconCooldownViewer"] = true,
    ["BuffBarCooldownViewer"] = true,
}

function HUCDM:InitAyjieInterop()
    if self.ayjieInterop then return end
    if not C_AddOns.IsAddOnLoaded("Ayije_CDM") then return end

    local CDM = _G.Ayije_CDM
    if not CDM then return end

    -- Version safety: verify required methods exist
    if not CDM.ForceReanchor or not CDM.RepositionBuffViewer
        or not CDM.GetOrCreateAnchorContainer then
        self:Print("HeadsUpCDM: Ayije_CDM version incompatible — disable one addon to prevent lockup")
        return
    end

    self.ayjieInterop = true
    self.ayjieCDM = CDM

    -- Patch 1: Skip ForceReanchor for our viewers.
    -- ForceReanchor is where Ayjie computes per-frame positions and writes
    -- fd.cdmAnchor. Skipping it makes Ayjie's per-frame SetPoint hooks inert
    -- (they check "if not cdmAnchor then return end").
    local origForceReanchor = CDM.ForceReanchor
    CDM.ForceReanchor = function(cdmSelf, viewer)
        local vName = viewer and viewer.GetName and viewer:GetName()
        if OWNED_VIEWERS[vName] then return false end
        return origForceReanchor(cdmSelf, viewer)
    end

    -- Patch 2: Skip RepositionBuffViewer for our buff viewer.
    -- Separate code path from ForceReanchor, triggered by OnActiveStateChanged.
    local origRepositionBuff = CDM.RepositionBuffViewer
    CDM.RepositionBuffViewer = function(cdmSelf, viewer)
        local vName = viewer and viewer.GetName and viewer:GetName()
        if vName == "BuffIconCooldownViewer" then return false end
        return origRepositionBuff(cdmSelf, viewer)
    end

    -- Patch 3: Block container creation for Buff/BuffBar viewers.
    -- Essential container is kept so Ayjie's Utility viewer can anchor to it.
    local origGetOrCreate = CDM.GetOrCreateAnchorContainer
    CDM.GetOrCreateAnchorContainer = function(cdmSelf, viewer)
        local vName = viewer and viewer.GetName and viewer:GetName()
        if vName == "BuffIconCooldownViewer" or vName == "BuffBarCooldownViewer" then
            return nil
        end
        return origGetOrCreate(cdmSelf, viewer)
    end

    -- Patch 4: Hide and remove existing Buff/BuffBar containers
    if CDM.anchorContainers then
        for _, vName in ipairs({"BuffIconCooldownViewer", "BuffBarCooldownViewer"}) do
            local container = CDM.anchorContainers[vName]
            if container and container.Hide then container:Hide() end
            CDM.anchorContainers[vName] = nil
        end
    end

    -- Patch 5: Disable Ayjie's rotation glow to prevent double-glow
    if CDM.db and CDM.db.rotationAssistEnabled then
        CDM.db.rotationAssistEnabled = false
    end

    self:Print("HeadsUpCDM: Ayije CDM detected — coexistence mode active")
end
