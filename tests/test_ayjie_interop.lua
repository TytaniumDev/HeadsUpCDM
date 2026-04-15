-- Tests for AyjieInterop: runtime patching of Ayije_CDM
-- Run with: busted tests/test_ayjie_interop.lua

-- MockFrame factory (minimal for interop tests)
local function MockFrame(name)
    local f = { name = name or "MockFrame", shown = true }
    function f:GetName() return self.name end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    return f
end

-- Stub WoW APIs
_G.LibStub = function(name)
    if name == "AceConfigDialog-3.0" then
        return { Open = function() end, AddToBlizOptions = function() end }
    elseif name == "AceConfig-3.0" then
        return { RegisterOptionsTable = function() end }
    end
    local addon = {}
    addon.NewAddon = function(_, addonName, ...)
        addon.name = addonName
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
_G.C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end }
_G.InCombatLockdown = function() return false end
_G.C_AddOns = { IsAddOnLoaded = function() return false end }

-- Load source files
dofile("src/Config.lua")
dofile("src/AyjieInterop.lua")

local HUCDM = _G.HeadsUpCDM

-- Stub UI module functions (not loaded in tests)
local noop = function() end
HUCDM.SetupOptions = noop
HUCDM.BuildDisplay = noop
HUCDM.TeardownDisplay = noop

describe("AyjieInterop", function()

    before_each(function()
        -- Reset state
        HUCDM.ayjieInterop = nil
        HUCDM.ayjieCDM = nil
        _G.Ayije_CDM = nil
        _G.C_AddOns.IsAddOnLoaded = function() return false end
    end)

    describe("when Ayjie is not loaded", function()
        it("should not activate interop", function()
            HUCDM:InitAyjieInterop()
            assert.is_nil(HUCDM.ayjieInterop)
        end)
    end)

    describe("when Ayjie is loaded but missing required methods", function()
        it("should not activate interop and warn", function()
            _G.C_AddOns.IsAddOnLoaded = function(name)
                return name == "Ayije_CDM"
            end
            _G.Ayije_CDM = { db = {} }

            local warned = false
            HUCDM.Print = function(_, msg)
                if msg and msg:find("incompatible") then warned = true end
            end

            HUCDM:InitAyjieInterop()
            assert.is_nil(HUCDM.ayjieInterop)
            assert.is_true(warned)

            HUCDM.Print = noop
        end)
    end)

    describe("when Ayjie is loaded with required methods", function()
        local CDM, forceReanchorCalled, repositionCalled, getOrCreateCalled, applyStyleCalled

        before_each(function()
            forceReanchorCalled = {}
            repositionCalled = {}
            getOrCreateCalled = {}
            applyStyleCalled = {}

            CDM = {
                ForceReanchor = function(self, viewer)
                    local vName = viewer and viewer:GetName()
                    forceReanchorCalled[#forceReanchorCalled + 1] = vName
                    return true
                end,
                RepositionBuffViewer = function(self, viewer)
                    local vName = viewer and viewer:GetName()
                    repositionCalled[#repositionCalled + 1] = vName
                    return true
                end,
                GetOrCreateAnchorContainer = function(self, viewer)
                    local vName = viewer and viewer:GetName()
                    getOrCreateCalled[#getOrCreateCalled + 1] = vName
                    return MockFrame(vName .. "_Container")
                end,
                ApplyStyle = function(self, frame, vName, forceUpdate)
                    applyStyleCalled[#applyStyleCalled + 1] = {
                        frame = frame, vName = vName, forceUpdate = forceUpdate,
                    }
                    return true
                end,
                anchorContainers = {},
                db = { rotationAssistEnabled = false },
            }

            _G.Ayije_CDM = CDM
            _G.C_AddOns.IsAddOnLoaded = function(name)
                return name == "Ayije_CDM"
            end

            HUCDM:InitAyjieInterop()
        end)

        it("should activate interop", function()
            assert.is_true(HUCDM.ayjieInterop)
            assert.equal(CDM, HUCDM.ayjieCDM)
        end)

        it("should skip ForceReanchor for Essential viewer", function()
            local viewer = MockFrame("EssentialCooldownViewer")
            local result = CDM:ForceReanchor(viewer)
            assert.is_false(result)
            assert.equal(0, #forceReanchorCalled)
        end)

        it("should skip ForceReanchor for BuffIcon viewer", function()
            local viewer = MockFrame("BuffIconCooldownViewer")
            local result = CDM:ForceReanchor(viewer)
            assert.is_false(result)
            assert.equal(0, #forceReanchorCalled)
        end)

        it("should skip ForceReanchor for BuffBar viewer", function()
            local viewer = MockFrame("BuffBarCooldownViewer")
            local result = CDM:ForceReanchor(viewer)
            assert.is_false(result)
            assert.equal(0, #forceReanchorCalled)
        end)

        it("should delegate ForceReanchor for Utility viewer", function()
            local viewer = MockFrame("UtilityCooldownViewer")
            local result = CDM:ForceReanchor(viewer)
            assert.is_true(result)
            assert.equal(1, #forceReanchorCalled)
            assert.equal("UtilityCooldownViewer", forceReanchorCalled[1])
        end)

        it("should skip RepositionBuffViewer for BuffIcon viewer", function()
            local viewer = MockFrame("BuffIconCooldownViewer")
            local result = CDM:RepositionBuffViewer(viewer)
            assert.is_false(result)
            assert.equal(0, #repositionCalled)
        end)

        it("should delegate RepositionBuffViewer for other viewers", function()
            local viewer = MockFrame("SomeOtherViewer")
            local result = CDM:RepositionBuffViewer(viewer)
            assert.is_true(result)
            assert.equal(1, #repositionCalled)
        end)

        it("should block GetOrCreateAnchorContainer for Buff viewer", function()
            local viewer = MockFrame("BuffIconCooldownViewer")
            local result = CDM:GetOrCreateAnchorContainer(viewer)
            assert.is_nil(result)
            assert.equal(0, #getOrCreateCalled)
        end)

        it("should block GetOrCreateAnchorContainer for BuffBar viewer", function()
            local viewer = MockFrame("BuffBarCooldownViewer")
            local result = CDM:GetOrCreateAnchorContainer(viewer)
            assert.is_nil(result)
            assert.equal(0, #getOrCreateCalled)
        end)

        it("should delegate GetOrCreateAnchorContainer for Essential viewer", function()
            local viewer = MockFrame("EssentialCooldownViewer")
            local result = CDM:GetOrCreateAnchorContainer(viewer)
            assert.is_not_nil(result)
            assert.equal(1, #getOrCreateCalled)
            assert.equal("EssentialCooldownViewer", getOrCreateCalled[1])
        end)

        it("should delegate GetOrCreateAnchorContainer for Utility viewer", function()
            local viewer = MockFrame("UtilityCooldownViewer")
            local result = CDM:GetOrCreateAnchorContainer(viewer)
            assert.is_not_nil(result)
            assert.equal(1, #getOrCreateCalled)
        end)

        it("should force-disable Ayjie rotation glow if enabled", function()
            -- Reset and re-init with glow enabled
            HUCDM.ayjieInterop = nil
            CDM.db.rotationAssistEnabled = true
            -- Re-store originals for re-patching
            CDM.ForceReanchor = function() return true end
            CDM.RepositionBuffViewer = function() return true end
            CDM.GetOrCreateAnchorContainer = function() return MockFrame("c") end
            CDM.ApplyStyle = function() return true end

            HUCDM:InitAyjieInterop()
            assert.is_false(CDM.db.rotationAssistEnabled)
        end)

        it("should skip ApplyStyle for Blizzard CDM frames in Essential viewer", function()
            local frame = { cooldownID = 12345 }
            CDM:ApplyStyle(frame, "EssentialCooldownViewer", true)
            assert.equal(0, #applyStyleCalled)
        end)

        it("should skip ApplyStyle for Blizzard CDM frames in BuffIcon viewer", function()
            local frame = { cooldownID = 12345 }
            CDM:ApplyStyle(frame, "BuffIconCooldownViewer", true)
            assert.equal(0, #applyStyleCalled)
        end)

        it("should skip ApplyStyle for Blizzard CDM frames in BuffBar viewer", function()
            local frame = { cooldownID = 12345 }
            CDM:ApplyStyle(frame, "BuffBarCooldownViewer", true)
            assert.equal(0, #applyStyleCalled)
        end)

        it("should delegate ApplyStyle for Ayjie tracker frames in Essential viewer", function()
            -- Trinkets/Defensives are passed vName=ESSENTIAL but lack cooldownID
            local frame = { isTrinket = true }
            CDM:ApplyStyle(frame, "EssentialCooldownViewer", true)
            assert.equal(1, #applyStyleCalled)
            assert.equal("EssentialCooldownViewer", applyStyleCalled[1].vName)
        end)

        it("should delegate ApplyStyle for Utility viewer frames", function()
            local frame = { cooldownID = 12345 }
            CDM:ApplyStyle(frame, "UtilityCooldownViewer", true)
            assert.equal(1, #applyStyleCalled)
        end)
    end)

    describe("container cleanup", function()
        it("should hide and nil existing Buff/BuffBar containers", function()
            local buffContainer = MockFrame("BuffContainer")
            local bbContainer = MockFrame("BuffBarContainer")

            local CDM = {
                ForceReanchor = function() return true end,
                RepositionBuffViewer = function() return true end,
                GetOrCreateAnchorContainer = function() return MockFrame("c") end,
                ApplyStyle = function() return true end,
                anchorContainers = {
                    ["BuffIconCooldownViewer"] = buffContainer,
                    ["BuffBarCooldownViewer"] = bbContainer,
                },
                db = { rotationAssistEnabled = false },
            }

            _G.Ayije_CDM = CDM
            _G.C_AddOns.IsAddOnLoaded = function(name)
                return name == "Ayije_CDM"
            end

            HUCDM:InitAyjieInterop()

            assert.is_false(buffContainer:IsShown())
            assert.is_false(bbContainer:IsShown())
            assert.is_nil(CDM.anchorContainers["BuffIconCooldownViewer"])
            assert.is_nil(CDM.anchorContainers["BuffBarCooldownViewer"])
        end)
    end)
end)
