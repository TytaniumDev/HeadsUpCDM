-- HeadsUpCDM: AceConfig-3.0 options panel

local HUCDM = _G.HeadsUpCDM

function HUCDM:SetupOptions()
    local options = {
        name = "HeadsUpCDM",
        type = "group",
        args = {

            general = {
                name = "General",
                type = "group",
                order = 1,
                args = {
                    enabled = {
                        name = "Enabled",
                        desc = "Enable or disable the addon display",
                        type = "toggle",
                        order = 1,
                        get = function() return self.db.profile.enabled end,
                        set = function(_, val)
                            self.db.profile.enabled = val
                            if val then self:BuildDisplay() else self:TeardownDisplay() end
                        end,
                    },
                    locked = {
                        name = "Lock Display",
                        desc = "Lock the display to prevent dragging. Unlock to reposition.",
                        type = "toggle",
                        order = 2,
                        get = function() return self.db.profile.locked end,
                        set = function(_, val)
                            self.db.profile.locked = val
                            self:UpdateDragBehavior()
                            self:UpdateBuffIcons()
                        end,
                    },
                    resetPos = {
                        name = "Reset Position",
                        type = "execute",
                        order = 3,
                        func = function()
                            self:ResetPosition()
                            if self.layoutFrame then
                                self.layoutFrame:ClearAllPoints()
                                local pos = self.db.profile.position
                                self.layoutFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
                            end
                        end,
                    },
                    openCDM = {
                        name = "Open Blizzard CDM Settings",
                        desc = "Open the built-in Cooldown Manager settings panel (or type /cdm)",
                        type = "execute",
                        order = 4,
                        func = function() self:OpenBlizzardCDM() end,
                    },
                },
            },

            layout = {
                name = "Layout",
                type = "group",
                order = 2,
                args = {
                    columnOrderDesc = {
                        name = "Column order: Buff Bars | Resource | Actions (default). "
                            .. "Change in SavedVariables for now.",
                        type = "description",
                        order = 1,
                    },
                    actionsAlpha = {
                        name = "Action Bar Opacity",
                        type = "range", min = 0.0, max = 1.0, step = 0.05,
                        order = 11,
                        get = function() return self.db.profile.layout.columns.actions.alpha end,
                        set = function(_, val)
                            self.db.profile.layout.columns.actions.alpha = val
                            if self.ReanchorCDMFrames then self:ReanchorCDMFrames() end
                            if self.ReanchorBuffIcons then self:ReanchorBuffIcons() end
                            self:ArrangeColumns()
                        end,
                    },
                    actionsSpacing = {
                        name = "Action Bar Spacing",
                        type = "range", min = 0, max = 20, step = 1,
                        order = 12,
                        get = function() return self.db.profile.layout.columns.actions.spacing end,
                        set = function(_, val)
                            self.db.profile.layout.columns.actions.spacing = val
                            self:RebuildDisplay()
                        end,
                    },
                    resourceAlpha = {
                        name = "Resource Bar Opacity",
                        type = "range", min = 0.0, max = 1.0, step = 0.05,
                        order = 21,
                        get = function() return self.db.profile.layout.columns.resource.alpha end,
                        set = function(_, val)
                            self.db.profile.layout.columns.resource.alpha = val
                            self:ArrangeColumns()
                        end,
                    },
                    buffBarsAlpha = {
                        name = "Buff Bars Opacity",
                        type = "range", min = 0.0, max = 1.0, step = 0.05,
                        order = 31,
                        get = function() return self.db.profile.layout.columns.buffBars.alpha end,
                        set = function(_, val)
                            self.db.profile.layout.columns.buffBars.alpha = val
                            self:ArrangeColumns()
                        end,
                    },
                },
            },

            resourceBar = {
                name = "Resource Bar",
                type = "group",
                order = 3,
                args = {
                    showText = {
                        name = "Show Numeric Overlay",
                        type = "toggle",
                        order = 1,
                        get = function() return self.db.profile.resourceBar.showText end,
                        set = function(_, val)
                            self.db.profile.resourceBar.showText = val
                            self:UpdateResourceBar()
                        end,
                    },
                },
            },

            buffBarsTab = {
                name = "Buff Bars",
                type = "group",
                order = 4,
                args = {
                    showIcons = {
                        name = "Show Buff Icons on Bars",
                        type = "toggle",
                        order = 1,
                        get = function() return self.db.profile.buffBars.showIcons end,
                        set = function(_, val)
                            self.db.profile.buffBars.showIcons = val
                            self:RebuildDisplay()
                        end,
                    },
                    showText = {
                        name = "Show Duration Text",
                        type = "toggle",
                        order = 2,
                        get = function() return self.db.profile.buffBars.showText end,
                        set = function(_, val)
                            self.db.profile.buffBars.showText = val
                        end,
                    },
                },
            },

            visuals = {
                name = "Visual Enhancements",
                type = "group",
                order = 5,
                args = {
                    desaturate = {
                        name = "Desaturate on Cooldown",
                        type = "toggle",
                        order = 1,
                        get = function() return self.db.profile.visuals.desaturateOnCooldown end,
                        set = function(_, val)
                            self.db.profile.visuals.desaturateOnCooldown = val
                        end,
                    },
                    coloredBorders = {
                        name = "Colored Borders",
                        type = "toggle",
                        order = 2,
                        get = function() return self.db.profile.visuals.coloredBorders end,
                        set = function(_, val)
                            self.db.profile.visuals.coloredBorders = val
                        end,
                    },
                    glowStyle = {
                        name = "Rotation Glow Style",
                        desc = "Choose the glow effect for the rotation helper highlight",
                        type = "select",
                        order = 3,
                        values = {
                            [1] = "Proc Glow (animated pulse)",
                            [2] = "Button Glow (classic WoW)",
                            [3] = "Pixel Glow (marching ants)",
                            [4] = "Autocast Shine (sparkle dots)",
                        },
                        get = function() return self.db.profile.visuals.glowStyle end,
                        set = function(_, val)
                            self.db.profile.visuals.glowStyle = val
                            if self.UpdateRotationHighlights then
                                self:UpdateRotationHighlights()
                            end
                        end,
                    },
                    glowColor = {
                        name = "Glow Color",
                        desc = "Color of the rotation glow effect",
                        type = "color",
                        order = 4,
                        get = function()
                            local c = self.db.profile.visuals.glowColor
                            return c[1], c[2], c[3]
                        end,
                        set = function(_, r, g, b)
                            self.db.profile.visuals.glowColor = { r, g, b }
                            if self.UpdateRotationHighlights then
                                self:UpdateRotationHighlights()
                            end
                        end,
                    },
                    glowSpeed = {
                        name = "Glow Speed",
                        desc = "Animation speed multiplier",
                        type = "range", min = 0.2, max = 3.0, step = 0.1,
                        order = 5,
                        get = function() return self.db.profile.visuals.glowSpeed end,
                        set = function(_, val)
                            self.db.profile.visuals.glowSpeed = val
                            if self.UpdateRotationHighlights then
                                self:UpdateRotationHighlights()
                            end
                        end,
                    },
                    glowThickness = {
                        name = "Glow Thickness",
                        desc = "Border thickness (Pixel Glow)",
                        type = "range", min = 1, max = 6, step = 1,
                        order = 6,
                        get = function() return self.db.profile.visuals.glowThickness end,
                        set = function(_, val)
                            self.db.profile.visuals.glowThickness = val
                            if self.UpdateRotationHighlights then
                                self:UpdateRotationHighlights()
                            end
                        end,
                    },
                    glowScale = {
                        name = "Glow Scale",
                        desc = "Size multiplier (Autocast Shine)",
                        type = "range", min = 0.5, max = 3.0, step = 0.1,
                        order = 7,
                        get = function() return self.db.profile.visuals.glowScale end,
                        set = function(_, val)
                            self.db.profile.visuals.glowScale = val
                            if self.UpdateRotationHighlights then
                                self:UpdateRotationHighlights()
                            end
                        end,
                    },
                    glowLines = {
                        name = "Glow Lines/Particles",
                        desc = "Number of particles or lines",
                        type = "range", min = 1, max = 16, step = 1,
                        order = 8,
                        get = function() return self.db.profile.visuals.glowLines end,
                        set = function(_, val)
                            self.db.profile.visuals.glowLines = val
                            if self.UpdateRotationHighlights then
                                self:UpdateRotationHighlights()
                            end
                        end,
                    },
                    buffCountdown = {
                        name = "Buff Icon Countdown Text",
                        type = "toggle",
                        order = 20,
                        get = function() return self.db.profile.visuals.buffCountdownText end,
                        set = function(_, val)
                            self.db.profile.visuals.buffCountdownText = val
                        end,
                    },
                },
            },
        },
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable("HeadsUpCDM", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("HeadsUpCDM", "HeadsUpCDM")
end
