-- Tests for SpellData: spec presets, buff pairings, and resource thresholds
-- Run with: busted tests/test_spell_data.lua

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

local HUCDM = _G.HeadsUpCDM

describe("SpellData", function()
    it("should expose SpellData table on addon", function()
        assert.is_not_nil(HUCDM.SpellData)
    end)

    it("should have presets for all four builds", function()
        local presets = HUCDM.SpellData.presets
        assert.is_not_nil(presets["BM_PACK_LEADER"])
        assert.is_not_nil(presets["BM_DARK_RANGER"])
        assert.is_not_nil(presets["MM_DARK_RANGER"])
        assert.is_not_nil(presets["MM_SENTINEL"])
    end)

    describe("BM Pack Leader preset", function()
        local preset
        setup(function()
            preset = HUCDM.SpellData.presets["BM_PACK_LEADER"]
        end)

        it("should have spells in order", function()
            assert.equal(34026, preset.spells[1].id)   -- Kill Command
            assert.equal(217200, preset.spells[2].id)   -- Barbed Shot
            assert.equal(19574, preset.spells[3].id)    -- Bestial Wrath
        end)

        it("should have buff pairings for Kill Command", function()
            local pairings = preset.spells[1].pairedBuffs
            assert.is_not_nil(pairings)
            assert.is_true(#pairings >= 2)
        end)

        it("should have Wild Thrash paired with Beast Cleave", function()
            local wildThrash = preset.spells[4]
            assert.equal("Wild Thrash", wildThrash.name)
            assert.is_true(#wildThrash.pairedBuffs >= 1)
        end)

        it("should have no paired buffs for Cobra Shot", function()
            local cobraShot = preset.spells[5]
            assert.equal("Cobra Shot", cobraShot.name)
            assert.equal(0, #cobraShot.pairedBuffs)
        end)
    end)

    describe("MM Dark Ranger preset", function()
        local preset
        setup(function()
            preset = HUCDM.SpellData.presets["MM_DARK_RANGER"]
        end)

        it("should pair Precise Shots with Arcane Shot", function()
            local arcaneShot = preset.spells[3]
            assert.equal("Arcane Shot", arcaneShot.name)
            assert.is_true(#arcaneShot.pairedBuffs >= 1)
            assert.equal("Precise Shots", arcaneShot.pairedBuffs[1].name)
        end)

        it("should pair Trueshot with Trueshot buff and Wailing Arrow", function()
            local trueshot = preset.spells[5]
            assert.equal("Trueshot", trueshot.name)
            assert.is_true(#trueshot.pairedBuffs >= 2)
        end)

        it("should mark Arcane Shot as actionbar source", function()
            local arcaneShot = preset.spells[3]
            assert.equal("Arcane Shot", arcaneShot.name)
            assert.equal("actionbar", arcaneShot.source)
        end)

        it("should pair Double Tap with Rapid Fire, not Aimed Shot", function()
            local aimedShot = preset.spells[1]
            local rapidFire = preset.spells[2]
            assert.equal("Aimed Shot", aimedShot.name)
            assert.equal("Rapid Fire", rapidFire.name)
            assert.equal(1, #aimedShot.pairedBuffs)
            assert.equal(389019, aimedShot.pairedBuffs[1].id)
            assert.equal(1, #rapidFire.pairedBuffs)
            assert.equal(473370, rapidFire.pairedBuffs[1].id)
        end)
    end)

    describe("MM Sentinel preset", function()
        local preset
        setup(function()
            preset = HUCDM.SpellData.presets["MM_SENTINEL"]
        end)

        it("should mark Arcane Shot as actionbar source", function()
            local arcaneShot = preset.spells[3]
            assert.equal("Arcane Shot", arcaneShot.name)
            assert.equal("actionbar", arcaneShot.source)
        end)

        it("should pair Double Tap with Rapid Fire, not Aimed Shot", function()
            local aimedShot = preset.spells[1]
            local rapidFire = preset.spells[2]
            assert.equal("Aimed Shot", aimedShot.name)
            assert.equal("Rapid Fire", rapidFire.name)
            assert.equal(1, #aimedShot.pairedBuffs)
            assert.equal(389019, aimedShot.pairedBuffs[1].id)
            assert.equal(1, #rapidFire.pairedBuffs)
            assert.equal(473370, rapidFire.pairedBuffs[1].id)
        end)
    end)

    describe("buff bar defaults", function()
        it("should have BM buff bar defaults", function()
            local bm = HUCDM.SpellData.presets["BM_PACK_LEADER"].buffBarDefaults
            assert.is_not_nil(bm)
            assert.is_true(#bm >= 3)
        end)

        it("should have MM buff bar defaults", function()
            local mm = HUCDM.SpellData.presets["MM_DARK_RANGER"].buffBarDefaults
            assert.is_not_nil(mm)
            assert.is_true(#mm >= 3)
        end)
    end)

    describe("resource thresholds", function()
        it("should have default thresholds for BM", function()
            local t = HUCDM.SpellData.presets["BM_PACK_LEADER"].resourceThresholds
            assert.is_not_nil(t)
            assert.is_not_nil(t.red)
            assert.is_not_nil(t.yellow)
        end)

        it("should have MM red threshold at 35 (Aimed Shot cost)", function()
            local t = HUCDM.SpellData.presets["MM_DARK_RANGER"].resourceThresholds
            assert.equal(35, t.red)
        end)
    end)

    describe("hero build detection markers", function()
        it("should define spellbook markers for build detection", function()
            local markers = HUCDM.SpellData.buildMarkers
            assert.is_not_nil(markers)
            assert.is_not_nil(markers.DARK_RANGER)
            assert.is_not_nil(markers.PACK_LEADER)
            assert.is_not_nil(markers.SENTINEL)
        end)
    end)

    describe("max spell slots", function()
        it("should not exceed 8 spells in any preset", function()
            for key, preset in pairs(HUCDM.SpellData.presets) do
                assert.is_true(#preset.spells <= 8,
                    key .. " has " .. #preset.spells .. " spells (max 8)")
            end
        end)
    end)

    describe("actionbar spell fields", function()
        it("should have bar and slot for MM_DARK_RANGER Arcane Shot", function()
            local preset = HUCDM.SpellData.presets["MM_DARK_RANGER"]
            local arcane
            for _, s in ipairs(preset.spells) do
                if s.source == "actionbar" then arcane = s; break end
            end
            assert.is_not_nil(arcane)
            assert.equal(8, arcane.bar)
            assert.equal(1, arcane.slot)
        end)

        it("should have bar and slot for MM_SENTINEL Arcane Shot", function()
            local preset = HUCDM.SpellData.presets["MM_SENTINEL"]
            local arcane
            for _, s in ipairs(preset.spells) do
                if s.source == "actionbar" then arcane = s; break end
            end
            assert.is_not_nil(arcane)
            assert.equal(8, arcane.bar)
            assert.equal(1, arcane.slot)
        end)
    end)
end)
