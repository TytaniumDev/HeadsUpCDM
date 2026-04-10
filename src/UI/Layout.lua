-- HeadsUpCDM: Master layout frame, column arrangement, drag, and anchor system

local HUCDM = _G.HeadsUpCDM

local COLUMN_GAP = 4

----------------------------------------------------------------------
-- Create the master anchor frame
----------------------------------------------------------------------
function HUCDM:CreateLayout()
    if self.layoutFrame then return self.layoutFrame end

    local frame = CreateFrame("Frame", "HUCDM_Layout", UIParent)
    frame:SetSize(200, 300)  -- initial size, will resize after columns register
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)

    -- Restore saved position
    local pos = self.db.profile.position
    frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)

    -- Drag overlay — visible when unlocked, covers the entire layout
    local drag = CreateFrame("Frame", "HUCDM_DragOverlay", frame)
    drag:SetAllPoints(frame)
    drag:SetFrameStrata("DIALOG")
    drag:EnableMouse(true)
    drag:SetMovable(true)
    drag:RegisterForDrag("LeftButton")

    drag:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, _, x, y = frame:GetPoint(1)
        self.db.profile.position = { point = point, x = x, y = y }
        -- Re-anchor ActionButtons to their new screen positions
        if self.TriggerActionBarHandlers then
            self:TriggerActionBarHandlers()
        end
    end)

    -- Semi-transparent background when unlocked
    local bg = drag:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.3)
    drag.bg = bg

    -- "Drag to move" label
    local label = drag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", drag, "TOP", 0, -4)
    label:SetText("HeadsUpCDM - Drag to move")
    label:SetTextColor(1, 0.84, 0, 0.8)
    drag.label = label

    drag:Hide()  -- hidden by default (locked)
    self.dragOverlay = drag

    self.layoutFrame = frame
    self.columns = {}

    self:UpdateDragBehavior()
    return frame
end

----------------------------------------------------------------------
-- Drag behavior: toggle drag overlay based on lock state
----------------------------------------------------------------------
function HUCDM:UpdateDragBehavior()
    local frame = self.layoutFrame
    if not frame then return end

    local locked = self.db.profile.locked
    frame:SetMovable(not locked)

    if self.dragOverlay then
        if locked then
            self.dragOverlay:Hide()
        else
            self.dragOverlay:Show()
        end
    end
end

----------------------------------------------------------------------
-- Register a column (called by each column module during setup)
----------------------------------------------------------------------
function HUCDM:RegisterColumn(key, colFrame)
    self.columns[key] = colFrame
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
    local totalWidth = 0
    local maxHeight = 0

    for i = 1, #order do
        local key = order[i]
        local col = self.columns[key]
        if col and col:IsShown() then
            col:ClearAllPoints()
            if not prevFrame then
                col:SetPoint("TOPLEFT", layout, "TOPLEFT", 0, 0)
            else
                col:SetPoint("TOPLEFT", prevFrame, "TOPRIGHT", COLUMN_GAP, 0)
                totalWidth = totalWidth + COLUMN_GAP
            end
            prevFrame = col

            -- Apply per-column settings (alpha only — scale was removed)
            local settings = self.db.profile.layout.columns[key]
            if settings then
                col:SetAlpha(settings.alpha)
            end

            totalWidth = totalWidth + col:GetWidth()
            local h = col:GetHeight()
            if h > maxHeight then maxHeight = h end
        end
    end

    -- Resize layout frame to fit all columns
    if totalWidth > 0 and maxHeight > 0 then
        layout:SetSize(totalWidth, maxHeight)
    end
end

----------------------------------------------------------------------
-- Teardown: hide layout, release columns
----------------------------------------------------------------------
function HUCDM:DestroyLayout()
    if self.dragOverlay then
        self.dragOverlay:Hide()
        self.dragOverlay = nil
    end
    if self.layoutFrame then
        self.layoutFrame:Hide()
        self.layoutFrame = nil
    end
    self.columns = {}
end
