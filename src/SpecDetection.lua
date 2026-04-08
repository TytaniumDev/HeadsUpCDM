-- HeadsUpCDM: Detect current spec and hero talent build, return preset key

local HUCDM = _G.HeadsUpCDM

--- Detect the current build based on spec index and spellbook contents.
--- @param specIndex number 1=BM, 2=MM (from C_SpecializationInfo.GetSpecialization())
--- @param isSpellKnown function(spellID) -> boolean (injectable for testing)
--- @return string|nil preset key like "BM_PACK_LEADER", or nil if unsupported
function HUCDM:DetectBuild(specIndex, isSpellKnown)
    local markers = self.SpellData.buildMarkers

    if specIndex == self.SpellData.SPEC_BM then
        if isSpellKnown(markers.DARK_RANGER) then
            return "BM_DARK_RANGER"
        end
        return "BM_PACK_LEADER"
    elseif specIndex == self.SpellData.SPEC_MM then
        if isSpellKnown(markers.DARK_RANGER) then
            return "MM_DARK_RANGER"
        end
        return "MM_SENTINEL"
    end

    return nil
end

--- Convenience wrapper using real WoW APIs. Call this at runtime.
--- @return string|nil preset key, or nil if unsupported spec
function HUCDM:DetectCurrentBuild()
    local specIndex = C_SpecializationInfo.GetSpecialization()
    return self:DetectBuild(specIndex, function(spellID)
        return IsSpellKnown(spellID)
    end)
end
