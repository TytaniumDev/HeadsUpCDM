-- HeadsUpCDM: Addon lifecycle, slash commands, event handlers

local HUCDM = _G.HeadsUpCDM

function HUCDM:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("HeadsUpCDMDB", self.defaults, true)
    self:RegisterChatCommand("headsupcdm", "SlashCommand")
    self:RegisterChatCommand("hucdm", "SlashCommand")
end

function HUCDM:OnEnable()
    self:Print("HeadsUpCDM loaded. Type /hucdm for options.")
end

function HUCDM:SlashCommand(input)
    local cmd = strtrim(input or "")
    if cmd == "" or cmd == "toggle" then
        self:Toggle()
    elseif cmd == "lock" then
        self:Lock()
    elseif cmd == "unlock" then
        self:Unlock()
    elseif cmd == "reset" then
        self:ResetPosition()
    else
        self:Print("Usage: /hucdm [toggle|lock|unlock|reset]")
    end
end

function HUCDM:Toggle()
    self.db.profile.enabled = not self.db.profile.enabled
    self:Print(self.db.profile.enabled and "Enabled" or "Disabled")
end

function HUCDM:Lock()
    self.db.profile.locked = true
    self:Print("Display locked.")
end

function HUCDM:Unlock()
    self.db.profile.locked = false
    self:Print("Display unlocked. Drag to reposition.")
end

function HUCDM:ResetPosition()
    self.db.profile.position = { point = "CENTER", x = 0, y = 200 }
    self:Print("Position reset to default.")
end
