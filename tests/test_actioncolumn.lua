-- Tests for ActionColumn: grab and position ActionButton frames for filler spells
-- Run with: busted tests/test_actioncolumn.lua

-- MockFrame factory
local function MockFrame(name)
    local f = {
        name = name or "MockFrame",
        shown = false,
        parent = nil,
        children = {},
        scripts = {},
        points = {},
        size = { w = 0, h = 0 },
        scale = 1.0,
        alpha = 1.0,
        strata = "MEDIUM",
        clamped = false,
        movable = false,
        mouseEnabled = false,
    }
    function f:SetSize(w, h) self.size.w = w; self.size.h = h end
    function f:GetWidth() return self.size.w end
    function f:GetHeight() return self.size.h end
    function f:SetPoint(point, relativeTo, relPoint, x, y)
        self.points[#self.points + 1] = { point, relativeTo, relPoint, x, y }
    end
    function f:ClearAllPoints() self.points = {} end
    function f:GetPoint(idx)
        local p = self.points[idx]
        if not p then return nil end
        return p[1], p[2], p[3], p[4], p[5]
    end
    function f:GetNumPoints() return #self.points end
    function f:SetScale(s) self.scale = s end
    function f:GetScale() return self.scale end
    function f:SetAlpha(a) self.alpha = a end
    function f:GetAlpha() return self.alpha end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetParent(p) self.parent = p end
    function f:GetParent() return self.parent end
    function f:SetFrameStrata(s) self.strata = s end
    function f:SetScript(event, handler) self.scripts[event] = handler end
    function f:CreateTexture(tName)
        local t = MockFrame(tName or "Texture")
        function t:SetColorTexture() end
        function t:SetAllPoints() end
        function t:SetTexture() end
        function t:SetDesaturated() end
        return t
    end
    function f:CreateFontString(fsName)
        local fs = MockFrame(fsName or "FontString")
        function fs:SetFont() end
        function fs:SetText() end
        function fs:SetTextColor() end
        function fs:GetText() return "" end
        function fs:SetAllPoints() end
        return fs
    end
    function f:SetAllPoints() end
    function f:SetClampedToScreen(v) self.clamped = v end
    function f:SetMovable(v) self.movable = v end
    function f:EnableMouse(v) self.mouseEnabled = v end
    function f:RegisterForDrag() end
    function f:RegisterEvent() end
    function f:UnregisterAllEvents() end
    function f:SetHeight(h) self.size.h = h end
    function f:SetWidth(w) self.size.w = w end
    f.attrs = {}
    f.frameRefs = {}
    function f:SetAttribute(k, v) self.attrs[k] = v end
    function f:GetAttribute(k) return self.attrs[k] end
    function f:SetFrameRef(k, ref) self.frameRefs[k] = ref end
    function f:GetFrameRef(k) return self.frameRefs[k] end
    function f:Execute() end  -- stub for SecureHandler restricted code
    return f
end

-- Stub LibStub to return a mock LibCustomGlow (ActionColumn.lua requires it)
local mockLCG = {
    ProcGlow_Start = function() end,
    ProcGlow_Stop = function() end,
    ButtonGlow_Start = function() end,
    ButtonGlow_Stop = function() end,
    PixelGlow_Start = function() end,
    PixelGlow_Stop = function() end,
    AutoCastGlow_Start = function() end,
    AutoCastGlow_Stop = function() end,
}

_G.LibStub = function(name)
    if name == "LibCustomGlow-1.0" then
        return mockLCG
    elseif name == "AceConfigDialog-3.0" then
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

-- Stub WoW APIs
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.C_Timer = {
    After = function(_, fn) if fn then fn() end end,
    NewTicker = function() return { Cancel = function() end } end,
}
_G.CreateFrame = function(_, name)
    return MockFrame(name)
end
_G.GetTime = function() return 0 end
_G.InCombatLockdown = function() return false end
_G.hooksecurefunc = function() end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end end
_G.UnitPower = function() return 100 end
_G.setmetatable = setmetatable
_G.C_CooldownViewer = { GetCooldownViewerCooldownInfo = function() return nil end }
_G.C_AssistedCombat = { GetNextCastSpell = function() return nil end }
_G.C_Spell = {
    GetSpellName = function() return nil end,
    GetBaseSpell = function() return nil end,
    GetSpellInfo = function() return { iconID = 132218 } end,
}
_G.EventRegistry = {
    RegisterCallback = function() end,
}
_G.AssistedCombatManager = nil
_G.CooldownViewerEssentialItemMixin = nil

-- Stub UIParent
_G.UIParent = MockFrame("UIParent")

-- Create mock ActionButton frames for MultiBar7
local multiBar7Parent = MockFrame("MultiBar7")
for i = 1, 12 do
    local btn = MockFrame("MultiBar7Button" .. i)
    btn.parent = multiBar7Parent
    btn:SetPoint("BOTTOMLEFT", multiBar7Parent, "BOTTOMLEFT", (i - 1) * 45, 0)
    btn.scale = 1.0
    btn.shown = true
    _G["MultiBar7Button" .. i] = btn
end

-- Load source files in order
dofile("src/Config.lua")
dofile("src/Core.lua")
dofile("src/SpellData.lua")

-- Stub all UI module functions
local HUCDM = _G.HeadsUpCDM
local noop = function() end
HUCDM.SetupOptions         = noop
HUCDM.BuildDisplay         = noop
HUCDM.TeardownDisplay      = noop
HUCDM.RebuildDisplay       = noop
HUCDM.UpdateDragBehavior   = noop
HUCDM.UpdateBuffIcons      = noop
HUCDM.UpdateResourceBar    = noop
HUCDM.UpdateBuffBars       = noop
HUCDM.ArrangeColumns       = noop
HUCDM.CreateLayout         = noop
HUCDM.SetupRotationGlow    = noop
HUCDM.CreateResourceBar    = noop
HUCDM.CreateBuffIcons      = noop
HUCDM.CreateBuffBars       = noop
HUCDM.DestroyBuffBars      = noop
HUCDM.DestroyBuffIcons     = noop
HUCDM.DestroyResourceBar   = noop
HUCDM.DestroyLayout        = noop
HUCDM.RescanActionButtons  = noop
HUCDM.DetectCurrentBuild   = noop
HUCDM.RegisterEvent        = HUCDM.RegisterEvent or noop
HUCDM.SetupCDMHooks        = noop
HUCDM.RegisterColumn       = noop
HUCDM.RelayoutRows         = noop

-- Load ActionColumn module (this defines CreateActionColumn, DestroyActionColumn, etc.)
dofile("src/UI/ActionColumn.lua")

-- Re-stub hooks that ActionColumn defines but we want to control
HUCDM.SetupCDMHooks        = noop
HUCDM.RegisterColumn       = noop
HUCDM.RelayoutRows         = noop

describe("ActionColumn", function()
    local preset

    before_each(function()
        HUCDM:OnInitialize()
        HUCDM.layoutFrame = MockFrame("HUCDM_Layout")
        HUCDM.layoutFrame.shown = true
        preset = HUCDM.SpellData.presets["MM_DARK_RANGER"]
        HUCDM.SetupCDMHooks = noop
        HUCDM.RelayoutRows = noop
        HUCDM.RegisterColumn = noop

        -- Reset mock buttons to original state
        for i = 1, 12 do
            local btn = _G["MultiBar7Button" .. i]
            btn.parent = multiBar7Parent
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOMLEFT", multiBar7Parent, "BOTTOMLEFT", (i - 1) * 45, 0)
            btn.scale = 1.0
            btn.shown = true
        end
    end)

    after_each(function()
        if HUCDM.actionBarButtons then
            HUCDM:DestroyActionColumn()
        end
        HUCDM.actionColumn = nil
        HUCDM.actionRows = {}
        HUCDM.cdmSpellSlots = {}
        HUCDM.actionBarButtons = nil
    end)

    describe("ResolveActionButton", function()
        it("should resolve bar 8 slot 1 to MultiBar7Button1", function()
            local btn = HUCDM:ResolveActionButton(8, 1)
            assert.equal(_G["MultiBar7Button1"], btn)
        end)

        it("should resolve bar 8 slot 5 to MultiBar7Button5", function()
            local btn = HUCDM:ResolveActionButton(8, 5)
            assert.equal(_G["MultiBar7Button5"], btn)
        end)

        it("should return nil for missing button", function()
            local btn = HUCDM:ResolveActionButton(8, 99)
            assert.is_nil(btn)
        end)

        it("should return nil for unknown bar number", function()
            local btn = HUCDM:ResolveActionButton(99, 1)
            assert.is_nil(btn)
        end)
    end)

    describe("CreateActionColumn with actionbar spells", function()
        it("should create a SecureHandler for Arcane Shot", function()
            HUCDM:CreateActionColumn(preset)
            assert.is_not_nil(HUCDM.actionBarButtons)
            assert.equal(1, #HUCDM.actionBarButtons)
            local entry = HUCDM.actionBarButtons[1]
            assert.is_not_nil(entry.handler)
            assert.equal(185358, entry.spellID)
        end)

        it("should register button, row, and uiParent as frame refs", function()
            HUCDM:CreateActionColumn(preset)
            local entry = HUCDM.actionBarButtons[1]
            local handler = entry.handler
            assert.equal(_G["MultiBar7Button1"], handler.frameRefs["btn"])
            assert.equal(entry.row, handler.frameRefs["row"])
            assert.is_not_nil(handler.frameRefs["uiParent"])
        end)

        it("should register original parent for restore", function()
            HUCDM:CreateActionColumn(preset)
            local entry = HUCDM.actionBarButtons[1]
            local handler = entry.handler
            assert.equal(multiBar7Parent, handler.frameRefs["origParent"])
        end)

        it("should set the reanchor attribute to trigger restricted code", function()
            HUCDM:CreateActionColumn(preset)
            local entry = HUCDM.actionBarButtons[1]
            local handler = entry.handler
            assert.is_not_nil(handler.attrs["hucdm-reanchor"])
        end)

        it("should set _onattributechanged snippet", function()
            HUCDM:CreateActionColumn(preset)
            local entry = HUCDM.actionBarButtons[1]
            local handler = entry.handler
            assert.is_not_nil(handler.attrs["_onattributechanged"])
            local snippet = handler.attrs["_onattributechanged"]
            assert.truthy(snippet:find("hucdm%-reanchor"))
            assert.truthy(snippet:find("hucdm%-restore"))
        end)

        it("should store row reference", function()
            HUCDM:CreateActionColumn(preset)
            local entry = HUCDM.actionBarButtons[1]
            local arcaneRow = HUCDM.actionRows[3]
            assert.equal(arcaneRow, entry.row)
        end)

        it("should mark the row as having an actionbar button", function()
            HUCDM:CreateActionColumn(preset)
            local arcaneRow = HUCDM.actionRows[3]
            assert.is_true(arcaneRow.hasActionBarButton)
        end)

        it("should fall back to static icon when button is missing", function()
            local saved = _G["MultiBar7Button1"]
            _G["MultiBar7Button1"] = nil

            HUCDM:CreateActionColumn(preset)
            local entry = HUCDM.actionBarButtons[1]
            assert.is_not_nil(entry.icon)
            assert.is_nil(entry.handler)

            _G["MultiBar7Button1"] = saved
        end)

        it("should not create handlers for CDM spells", function()
            local bmPreset = HUCDM.SpellData.presets["BM_PACK_LEADER"]
            HUCDM:CreateActionColumn(bmPreset)
            assert.is_not_nil(HUCDM.actionBarButtons)
            assert.equal(0, #HUCDM.actionBarButtons)
        end)
    end)

    describe("DestroyActionColumn cleanup", function()
        it("should trigger restore on SecureHandler entries", function()
            HUCDM:CreateActionColumn(preset)
            local handler = HUCDM.actionBarButtons[1].handler
            assert.is_not_nil(handler)
            HUCDM:DestroyActionColumn()
            assert.is_not_nil(handler.attrs["hucdm-restore"])
        end)

        it("should hide fallback icon entries", function()
            local saved = _G["MultiBar7Button1"]
            _G["MultiBar7Button1"] = nil

            HUCDM:CreateActionColumn(preset)
            local icon = HUCDM.actionBarButtons[1].icon
            HUCDM:DestroyActionColumn()
            assert.is_false(icon.shown)

            _G["MultiBar7Button1"] = saved
        end)

        it("should clear actionBarButtons table", function()
            HUCDM:CreateActionColumn(preset)
            HUCDM:DestroyActionColumn()
            assert.equal(0, #HUCDM.actionBarButtons)
        end)
    end)

    describe("RelayoutRows with actionbar spells", function()
        before_each(function()
            -- Re-enable real RelayoutRows for this block
            HUCDM.RelayoutRows = nil
            dofile("src/UI/ActionColumn.lua")
            HUCDM.SetupCDMHooks = noop
            HUCDM.RegisterColumn = noop
        end)

        it("should keep actionbar rows visible even without CDM frames", function()
            HUCDM:CreateActionColumn(preset)

            -- Simulate: no CDM frames found, only actionbar rows exist
            for _, row in ipairs(HUCDM.actionRows) do
                if not row.hasActionBarButton then
                    row.hasCDMFrame = false
                end
            end

            HUCDM:RelayoutRows()

            local arcaneRow = HUCDM.actionRows[3]
            assert.is_true(arcaneRow:IsShown())
        end)

        it("should count actionbar rows in visible total", function()
            HUCDM:CreateActionColumn(preset)

            -- Mark only actionbar rows as having content
            for _, row in ipairs(HUCDM.actionRows) do
                row.hasCDMFrame = row.hasActionBarButton or false
            end

            HUCDM:RelayoutRows()

            -- Column should have non-zero height (at least the actionbar row)
            assert.is_true(HUCDM.actionColumn:GetHeight() > 0)
        end)
    end)

    describe("ReanchorCDMFrames with actionbar spells", function()
        it("should apply scale to SecureHandler buttons via pcall", function()
            HUCDM.SetupCDMHooks = noop
            HUCDM.RegisterColumn = noop
            HUCDM.RelayoutRows = noop

            HUCDM:CreateActionColumn(preset)
            HUCDM.db.profile.layout.columns.actions.scale = 1.5

            local mockPool = { EnumerateActive = function() return function() end end }
            _G.EssentialCooldownViewer = { itemFramePool = mockPool }
            HUCDM:ReanchorCDMFrames()
            _G.EssentialCooldownViewer = nil

            local btn = HUCDM.actionBarButtons[1].btn
            assert.equal(1.5, btn.scale)
        end)

        it("should apply scale to fallback icons", function()
            local saved = _G["MultiBar7Button1"]
            _G["MultiBar7Button1"] = nil

            HUCDM.SetupCDMHooks = noop
            HUCDM.RegisterColumn = noop
            HUCDM.RelayoutRows = noop

            HUCDM:CreateActionColumn(preset)
            HUCDM.db.profile.layout.columns.actions.scale = 1.5

            local mockPool = { EnumerateActive = function() return function() end end }
            _G.EssentialCooldownViewer = { itemFramePool = mockPool }
            HUCDM:ReanchorCDMFrames()
            _G.EssentialCooldownViewer = nil

            local icon = HUCDM.actionBarButtons[1].icon
            assert.equal(1.5, icon.scale)

            _G["MultiBar7Button1"] = saved
        end)
    end)
end)
