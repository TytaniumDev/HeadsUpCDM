-- Luacheck configuration for HeadsUpCDM addon
std = "lua51"
max_line_length = 120

-- Allow setting fields on writable globals (WoW addon pattern where methods
-- are defined across multiple files via `local HUCDM = _G.HeadsUpCDM`
-- then `function HUCDM:Method() end`).
globals = {
    -- _G is written to by WoW addons to register their namespace
    _G = { other_fields = true },

    -- The addon namespace — methods are added to this table across all files
    HeadsUpCDM = { other_fields = true },

    -- WoW slash command globals
    "SLASH_HEADSUPCDM1",
    "SLASH_HEADSUPCDM2",
    SlashCmdList = { other_fields = true },
    UISpecialFrames = { other_fields = true },
}

read_globals = {
    -- Lua globals
    "os",

    -- WoW API functions
    "C_Timer",
    "CreateFrame",
    "GetTime",
    "hooksecurefunc",
    "IsInGroup",
    C_Spell = { other_fields = true },
    C_SpecializationInfo = { other_fields = true },
    "GetNumSpecializations",
    "GetNormalizedRealmName",
    "UnitClass",
    "UnitName",
    "UnitLevel",
    "date",
    "time",

    -- WoW UI globals
    "ChatFontNormal",
    "CreateColor",
    "GameFontNormal",
    "GameFontNormalLarge",
    "GameFontHighlightSmall",
    "GameFontNormalSmall",
    Settings = { other_fields = true },
    "SOUNDKIT",
    "UIParent",
    "BackdropTemplateMixin",

    -- Libraries
    "LibStub",

    -- Lua builtins in WoW
    "strtrim",
    "wipe",
    "table",
    "string",
    "math",
    "pairs",
    "ipairs",
    "setmetatable",
    "tostring",
    "tonumber",
    "type",
    "select",
    "unpack",
    "print",
}

-- Ignore unused self in methods (common WoW addon pattern)
self = false

-- Per-file overrides
files["tests/**"] = {
    -- In tests, allow unused arguments (stub callbacks), unused functions
    -- (prebuilt player constructors kept for reference), and unused varargs.
    ignore = { "21.", "211", "212", "213" },
    globals = {
        _G = { other_fields = true },
        "os",
        "LibStub",
        "wipe",
        HeadsUpCDM = { other_fields = true },
    },
    read_globals = {
        "dofile",
        "describe",
        "it",
        "assert",
        "before_each",
        "after_each",
        "setup",
        "teardown",
        "pending",
        "spy",
        "stub",
        "mock",
    },
}
