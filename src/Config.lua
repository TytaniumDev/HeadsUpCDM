-- HeadsUpCDM: Addon object creation, constants, and saved variable defaults

local HUCDM = LibStub("AceAddon-3.0"):NewAddon("HeadsUpCDM", "AceConsole-3.0", "AceEvent-3.0")
_G.HeadsUpCDM = HUCDM

-- Saved variable defaults
HUCDM.defaults = {
    profile = {
        enabled = true,
        locked = false,
        scale = 1.0,
        alpha = 1.0,
        position = { point = "CENTER", x = 0, y = 200 },

        layout = {
            columnOrder = { "buffBars", "resource", "actions" },
            columns = {
                actions  = { scale = 1.0, alpha = 1.0, spacing = 6, padding = 0 },
                resource = { scale = 1.0, alpha = 1.0, spacing = 6, padding = 0 },
                buffBars = { scale = 1.0, alpha = 1.0, spacing = 3, padding = 0 },
            },
        },

        resourceBar = {
            showText = true,
            thresholdOverrides = {},  -- per-spec overrides; empty = use SpellData defaults
            colorOverrides = {},
        },

        buffBars = {
            overrides = {},           -- per-spec overrides for which buffs to show
            showIcons = true,
            showText = true,
        },

        visuals = {
            desaturateOnCooldown = false,
            coloredBorders = false,
            readyColor = { 0, 1, 0 },
            cooldownColor = { 1, 0, 0 },
            glowColor = { 1, 0.84, 0 },
            glowStyle = 1,  -- 1=Proc, 2=Button, 3=Pixel, 4=Autocast
            buffCountdownText = false,
            buffCountdownFontSize = 12,
        },

        anchor = {
            target = "NONE",
            offsetX = 0,
            offsetY = 0,
        },

        spellOverrides = {},          -- per-spec overrides for spell list/pairings
    },
}
