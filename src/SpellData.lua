-- HeadsUpCDM: Spell presets, buff pairings, and resource thresholds per spec/build

local HUCDM = _G.HeadsUpCDM

HUCDM.SpellData = {}

----------------------------------------------------------------------
-- Hero build detection: spellIDs that indicate which hero tree is active
----------------------------------------------------------------------
HUCDM.SpellData.buildMarkers = {
    DARK_RANGER = 466930,       -- Black Arrow (hero talent ability)
    PACK_LEADER = 424687,       -- Howl of the Pack Leader (hero talent passive)
    SENTINEL    = 429444,       -- Moonlight Chakram (hero talent ability)
}

----------------------------------------------------------------------
-- Spec IDs (from C_SpecializationInfo)
----------------------------------------------------------------------
HUCDM.SpellData.SPEC_BM = 1
HUCDM.SpellData.SPEC_MM = 2

----------------------------------------------------------------------
-- Presets: spell lists, paired buffs, buff bar defaults, resource thresholds
----------------------------------------------------------------------
HUCDM.SpellData.presets = {

    -- BM Hunter — Pack Leader
    BM_PACK_LEADER = {
        spells = {
            {
                id = 34026, name = "Kill Command",
                pairedBuffs = {
                    { id = 1273126, name = "Nature's Ally" },
                    { id = 424687, name = "Howl of the Pack Leader" },
                },
            },
            { id = 217200, name = "Barbed Shot", pairedBuffs = {} },
            {
                id = 19574, name = "Bestial Wrath",
                pairedBuffs = {
                    { id = 19574, name = "Bestial Wrath", isBuff = true },
                },
            },
            {
                id = 1264359, name = "Wild Thrash",
                pairedBuffs = {
                    { id = 115939, name = "Beast Cleave" },
                },
            },
            { id = 193455, name = "Cobra Shot", pairedBuffs = {} },
        },
        buffBarDefaults = {
            { id = 19574,  name = "Bestial Wrath", color = { 0.83, 0.33, 0 } },
            { id = 1273126, name = "Nature's Ally", color = { 0.12, 0.52, 0.29 } },
            { id = 115939, name = "Beast Cleave", color = { 0.16, 0.50, 0.73 } },
        },
        resourceThresholds = {
            red = 30,       -- Kill Command cost
            yellow = 60,
        },
    },

    -- BM Hunter — Dark Ranger
    BM_DARK_RANGER = {
        spells = {
            {
                id = 34026, name = "Kill Command",
                pairedBuffs = {
                    { id = 1273126, name = "Nature's Ally" },
                },
            },
            {
                id = 466930, name = "Black Arrow",
                pairedBuffs = {
                    { id = 466990, name = "Withering Fire" },
                },
            },
            { id = 217200, name = "Barbed Shot", pairedBuffs = {} },
            {
                id = 19574, name = "Bestial Wrath",
                pairedBuffs = {
                    { id = 19574, name = "Bestial Wrath", isBuff = true },
                },
            },
            { id = 459555, name = "Wailing Arrow", pairedBuffs = {} },
            {
                id = 1264359, name = "Wild Thrash",
                pairedBuffs = {
                    { id = 115939, name = "Beast Cleave" },
                },
            },
            { id = 193455, name = "Cobra Shot", pairedBuffs = {} },
        },
        buffBarDefaults = {
            { id = 19574,  name = "Bestial Wrath", color = { 0.83, 0.33, 0 } },
            { id = 1273126, name = "Nature's Ally", color = { 0.12, 0.52, 0.29 } },
            { id = 115939, name = "Beast Cleave", color = { 0.16, 0.50, 0.73 } },
        },
        resourceThresholds = {
            red = 30,
            yellow = 60,
        },
    },

    -- MM Hunter — Dark Ranger
    MM_DARK_RANGER = {
        spells = {
            {
                id = 19434, name = "Aimed Shot",
                pairedBuffs = {
                    { id = 389019, name = "Bulletstorm" },
                    { id = 473370, name = "Double Tap" },
                },
            },
            { id = 257044, name = "Rapid Fire", pairedBuffs = {} },
            {
                id = 185358, name = "Arcane Shot",
                source = "actionbar",
                pairedBuffs = {
                    { id = 260240, name = "Precise Shots" },
                },
            },
            { id = 466930, name = "Black Arrow", pairedBuffs = {} },
            {
                id = 288613, name = "Trueshot",
                pairedBuffs = {
                    { id = 288613, name = "Trueshot", isBuff = true },
                    { id = 459555, name = "Wailing Arrow" },
                },
            },
            { id = 260243, name = "Volley", pairedBuffs = {} },
            { id = 56641, name = "Steady Shot", pairedBuffs = {} },
        },
        buffBarDefaults = {
            { id = 288613, name = "Trueshot", color = { 0.20, 0.60, 0.86 } },
            { id = 389019, name = "Bulletstorm", color = { 0.91, 0.30, 0.24 } },
            { id = 260240, name = "Precise Shots", color = { 0.61, 0.35, 0.71 } },
        },
        resourceThresholds = {
            red = 35,       -- Aimed Shot cost
            yellow = 70,
        },
    },

    -- MM Hunter — Sentinel
    MM_SENTINEL = {
        spells = {
            {
                id = 19434, name = "Aimed Shot",
                pairedBuffs = {
                    { id = 389019, name = "Bulletstorm" },
                    { id = 473370, name = "Double Tap" },
                },
            },
            { id = 257044, name = "Rapid Fire", pairedBuffs = {} },
            {
                id = 185358, name = "Arcane Shot",
                source = "actionbar",
                pairedBuffs = {
                    { id = 260240, name = "Precise Shots" },
                },
            },
            {
                id = 288613, name = "Trueshot",
                pairedBuffs = {
                    { id = 288613, name = "Trueshot", isBuff = true },
                    { id = 1264902, name = "Moonlight Chakram" },
                },
            },
            { id = 260243, name = "Volley", pairedBuffs = {} },
            { id = 56641, name = "Steady Shot", pairedBuffs = {} },
        },
        buffBarDefaults = {
            { id = 288613, name = "Trueshot", color = { 0.20, 0.60, 0.86 } },
            { id = 389019, name = "Bulletstorm", color = { 0.91, 0.30, 0.24 } },
            { id = 260240, name = "Precise Shots", color = { 0.61, 0.35, 0.71 } },
        },
        resourceThresholds = {
            red = 35,
            yellow = 70,
        },
    },
}
