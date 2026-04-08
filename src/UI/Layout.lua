-- HeadsUpCDM: Master layout frame, column arrangement, drag, and anchor system

local HUCDM = _G.HeadsUpCDM

local COLUMN_GAP = 4

----------------------------------------------------------------------
-- Create the master anchor frame
----------------------------------------------------------------------
function HUCDM:CreateLayout()
    if self.layoutFrame then return self.layoutFrame end

    local frame = CreateFrame("Frame", "HUCDM_Layout", UIParent)
    frame:SetSize(1, 1)  -- will resize dynamically based on content
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)

    -- Restore saved position
    local pos = self.db.profile.position
    frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    self.layoutFrame = frame
    self.columns = {}

    self:UpdateDragBehavior()
    return frame
end

----------------------------------------------------------------------
-- Drag behavior: group drag by default, shift+drag for individual columns
----------------------------------------------------------------------
function HUCDM:UpdateDragBehavior()
    local frame = self.layoutFrame
    if not frame then return end

    local locked = self.db.profile.locked
    frame:SetMovable(not locked)
    frame:EnableMouse(not locked)

    if not locked then
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(f)
            if not IsShiftKeyDown() then
                f:StartMoving()
            end
        end)
        frame:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()
            -- Save position
            local point, _, _, x, y = f:GetPoint(1)
            self.db.profile.position = { point = point, x = x, y = y }
        end)
    else
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
    end
end

----------------------------------------------------------------------
-- Register a column (called by each column module during setup)
----------------------------------------------------------------------
function HUCDM:RegisterColumn(key, frame)
    self.columns[key] = frame
    self:ArrangeColumns()
end

----------------------------------------------------------------------
-- Arrange columns left-to-right per saved column order
----------------------------------------------------------------------
function HUCDM:ArrangeColumns()
    local layout = self.layoutFrame
    if not layout then return end

    local order = self.db.profile.layout.columnOrder
    local prevFrame = nil

    for i = 1, #order do
        local key = order[i]
        local col = self.columns[key]
        if col and col:IsShown() then
            col:ClearAllPoints()
            if not prevFrame then
                col:SetPoint("TOPLEFT", layout, "TOPLEFT", 0, 0)
            else
                col:SetPoint("TOPLEFT", prevFrame, "TOPRIGHT", COLUMN_GAP, 0)
            end
            prevFrame = col

            -- Apply per-column settings
            local settings = self.db.profile.layout.columns[key]
            if settings then
                col:SetScale(settings.scale)
                col:SetAlpha(settings.alpha)
            end
        end
    end
end

----------------------------------------------------------------------
-- Apply anchor to a target frame
----------------------------------------------------------------------
function HUCDM:ApplyAnchor()
    local frame = self.layoutFrame
    if not frame then return end

    local anchor = self.db.profile.anchor
    if anchor.target == "NONE" then return end

    local target = _G[anchor.target]
    if not target then return end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", target, "CENTER", anchor.offsetX, anchor.offsetY)
end

----------------------------------------------------------------------
-- Teardown: hide layout, release columns
----------------------------------------------------------------------
function HUCDM:DestroyLayout()
    if self.layoutFrame then
        self.layoutFrame:Hide()
    end
    self.columns = {}
end
