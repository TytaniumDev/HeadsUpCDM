-- Tests for SpecDetection: spec and hero build identification
-- Run with: busted tests/test_spec_detection.lua

_G.LibStub = function()
    local addon = {}
    addon.NewAddon = function(_, name, ...)
        addon.name = name
        addon.Print = function() end
        addon.RegisterChatCommand = function() end
        addon.RegisterEvent = function() end
        addon.UnregisterAllEvents = function() end
        return addon
    end
    addon.New = function(_, _name, defaults)
        return { profile = defaults and defaults.profile or {} }
    end
    return addon
end
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

dofile("src/Config.lua")
dofile("src/Core.lua")
dofile("src/SpellData.lua")
dofile("src/SpecDetection.lua")

local HUCDM = _G.HeadsUpCDM

describe("SpecDetection", function()
    it("should expose DetectBuild on addon", function()
        assert.is_not_nil(HUCDM.DetectBuild)
    end)

    describe("DetectBuild", function()
        it("should return BM_PACK_LEADER for BM spec with Pack Leader marker", function()
            local knownSpells = { [424687] = true }  -- Howl of the Pack Leader
            local key = HUCDM:DetectBuild(1, function(id) return knownSpells[id] or false end)
            assert.equal("BM_PACK_LEADER", key)
        end)

        it("should return BM_DARK_RANGER for BM spec with Dark Ranger marker", function()
            local knownSpells = { [472925] = true }  -- Black Arrow
            local key = HUCDM:DetectBuild(1, function(id) return knownSpells[id] or false end)
            assert.equal("BM_DARK_RANGER", key)
        end)

        it("should return MM_DARK_RANGER for MM spec with Dark Ranger marker", function()
            local knownSpells = { [472925] = true }  -- Black Arrow
            local key = HUCDM:DetectBuild(2, function(id) return knownSpells[id] or false end)
            assert.equal("MM_DARK_RANGER", key)
        end)

        it("should return MM_SENTINEL for MM spec with Sentinel marker", function()
            local knownSpells = { [429444] = true }  -- Moonlight Chakram
            local key = HUCDM:DetectBuild(2, function(id) return knownSpells[id] or false end)
            assert.equal("MM_SENTINEL", key)
        end)

        it("should return nil for unsupported spec index", function()
            local key = HUCDM:DetectBuild(3, function() return false end)
            assert.is_nil(key)
        end)

        it("should fall back to Pack Leader for BM with no hero markers", function()
            local key = HUCDM:DetectBuild(1, function() return false end)
            assert.equal("BM_PACK_LEADER", key)
        end)

        it("should fall back to Sentinel for MM with no hero markers", function()
            local key = HUCDM:DetectBuild(2, function() return false end)
            assert.equal("MM_SENTINEL", key)
        end)
    end)
end)
