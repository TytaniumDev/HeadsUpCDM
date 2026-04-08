-- Tests for HeadsUpCDM addon initialization and configuration
-- Run with: busted tests/test_config.lua

-- Minimal stubs for WoW APIs and libraries
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

-- Load source files in order
dofile("src/Config.lua")
dofile("src/Core.lua")

local HUCDM = _G.HeadsUpCDM

describe("Config", function()
    it("should register the addon in _G", function()
        assert.is_not_nil(_G.HeadsUpCDM)
    end)

    it("should have default saved variable settings", function()
        assert.is_not_nil(HUCDM.defaults)
        assert.is_not_nil(HUCDM.defaults.profile)
    end)

    it("should default enabled to true", function()
        assert.is_true(HUCDM.defaults.profile.enabled)
    end)

    it("should default locked to false", function()
        assert.is_false(HUCDM.defaults.profile.locked)
    end)

    it("should default scale to 1.0", function()
        assert.equal(1.0, HUCDM.defaults.profile.scale)
    end)

    it("should default position to center-top", function()
        local pos = HUCDM.defaults.profile.position
        assert.equal("CENTER", pos.point)
        assert.equal(0, pos.x)
        assert.equal(200, pos.y)
    end)
end)

describe("Core", function()
    describe("OnInitialize", function()
        it("should set up the database", function()
            HUCDM:OnInitialize()
            assert.is_not_nil(HUCDM.db)
            assert.is_not_nil(HUCDM.db.profile)
        end)
    end)

    describe("Toggle", function()
        before_each(function()
            HUCDM:OnInitialize()
        end)

        it("should toggle enabled state", function()
            assert.is_true(HUCDM.db.profile.enabled)
            HUCDM:Toggle()
            assert.is_false(HUCDM.db.profile.enabled)
            HUCDM:Toggle()
            assert.is_true(HUCDM.db.profile.enabled)
        end)
    end)

    describe("Lock/Unlock", function()
        before_each(function()
            HUCDM:OnInitialize()
        end)

        it("should lock the display", function()
            HUCDM:Lock()
            assert.is_true(HUCDM.db.profile.locked)
        end)

        it("should unlock the display", function()
            HUCDM:Lock()
            HUCDM:Unlock()
            assert.is_false(HUCDM.db.profile.locked)
        end)
    end)

    describe("ResetPosition", function()
        before_each(function()
            HUCDM:OnInitialize()
        end)

        it("should reset position to defaults", function()
            HUCDM.db.profile.position = { point = "TOPLEFT", x = 100, y = -50 }
            HUCDM:ResetPosition()
            assert.equal("CENTER", HUCDM.db.profile.position.point)
            assert.equal(0, HUCDM.db.profile.position.x)
            assert.equal(200, HUCDM.db.profile.position.y)
        end)
    end)

    describe("SlashCommand", function()
        before_each(function()
            HUCDM:OnInitialize()
        end)

        it("should toggle on empty input", function()
            local initial = HUCDM.db.profile.enabled
            HUCDM:SlashCommand("")
            assert.not_equal(initial, HUCDM.db.profile.enabled)
        end)

        it("should toggle on 'toggle' input", function()
            local initial = HUCDM.db.profile.enabled
            HUCDM:SlashCommand("toggle")
            assert.not_equal(initial, HUCDM.db.profile.enabled)
        end)

        it("should lock on 'lock' input", function()
            HUCDM:SlashCommand("lock")
            assert.is_true(HUCDM.db.profile.locked)
        end)

        it("should unlock on 'unlock' input", function()
            HUCDM:SlashCommand("lock")
            HUCDM:SlashCommand("unlock")
            assert.is_false(HUCDM.db.profile.locked)
        end)

        it("should reset on 'reset' input", function()
            HUCDM.db.profile.position = { point = "TOPLEFT", x = 50, y = -50 }
            HUCDM:SlashCommand("reset")
            assert.equal("CENTER", HUCDM.db.profile.position.point)
        end)
    end)
end)
