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
    },
}
