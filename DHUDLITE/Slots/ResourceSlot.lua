local ADDON_NAME, ns = ...

local ResourceSlot = ns.CreateClass(ns.SlotBase, {})
ns.ResourceSlot = ResourceSlot

local Colorize = ns.Colorize
local Textures = ns.Textures
local EllipseMath = ns.EllipseMath

-- Combo point color textures by index
local COMBO_COLORS = {
    "ComboCircleRed",
    "ComboCircleOrange",
    "ComboCircleJadeGreen",
    "ComboCircleCyan",
    "ComboCircleGreen",
    "ComboCirclePurple",
}

function ResourceSlot:New()
    local o = ResourceSlot.__index.New(self)
    o.comboFrames = nil
    o.runeFrames = nil
    o.lastCount = 0
    o.lastCountMax = 0
    o.isPositioned = false
    return o
end

function ResourceSlot:Init(comboFrames, runeFrames)
    self.comboFrames = comboFrames
    self.runeFrames = runeFrames
end

function ResourceSlot:Activate()
    ns.SlotBase.Activate(self)
    if self.tracker then
        self:BindTracker(self.tracker, {
            DataChanged = self.OnDataChanged,
        })
        self.tracker:StartTracking()
        self:OnDataChanged()
    end
end

function ResourceSlot:Deactivate()
    if self.tracker then
        self.tracker:StopTracking()
    end
    self:HideAll()
    ns.SlotBase.Deactivate(self)
end

function ResourceSlot:HideAll()
    if self.comboFrames then
        for i = 1, #self.comboFrames do
            self.comboFrames[i]:Hide()
        end
    end
    if self.runeFrames then
        for i = 1, #self.runeFrames do
            self.runeFrames[i]:Hide()
        end
    end
    self.lastCount = 0
    self.lastCountMax = 0
    self.isPositioned = false
end

function ResourceSlot:OnDataChanged()
    if not self.isActive or not self.tracker then return end
    local t = self.tracker
    local CT = ns.ComboTracker

    if t.resourceType == CT.TYPE_NONE then
        self:HideAll()
        return
    end

    if t.resourceType == CT.TYPE_RUNES then
        self:UpdateRunes()
    else
        self:UpdateComboPoints()
    end
end

function ResourceSlot:UpdateComboPoints()
    local t = self.tracker
    local count = t.count
    local countMax = t.countMax
    if not self.comboFrames or countMax <= 0 then
        self:HideAll()
        return
    end

    -- Reposition if max changed
    if countMax ~= self.lastCountMax then
        self.isPositioned = false
        self.lastCountMax = countMax
    end

    if not self.isPositioned then
        local scale = ns.Settings:Get("scaleResources") or 1.0
        -- Place combo/resource bubbles on the right side to align with player power
        EllipseMath:PositionFramesAlongArc(self.comboFrames, countMax, 20, scale,
            EllipseMath.HUD_BAR_WIDTH, 5, false)
        self.isPositioned = true
    end

    -- Show/hide frames
    for i = 1, countMax do
        local frame = self.comboFrames[i]
        if frame then
            if i <= count then
                -- Set color based on position
                local colorIdx = ((i - 1) % #COMBO_COLORS) + 1
                local texName = COMBO_COLORS[colorIdx]
                local info = Textures.list[texName]
                if info and frame.texture then
                    frame.texture:SetTexture(info[1])
                    frame.texture:SetTexCoord(info[2], info[3], info[4], info[5])
                end
                frame:Show()
            else
                frame:Hide()
            end
        end
    end

    -- Hide excess frames
    for i = countMax + 1, #self.comboFrames do
        if self.comboFrames[i] then
            self.comboFrames[i]:Hide()
        end
    end

    self.lastCount = count
end

function ResourceSlot:UpdateRunes()
    local t = self.tracker
    if not self.runeFrames then return end

    -- Position rune frames if needed
    if not self.isPositioned then
        local scale = ns.Settings:Get("scaleResources") or 1.0
        -- Place runes on the right side as well
        EllipseMath:PositionFramesAlongArc(self.runeFrames, 6, 30, scale,
            EllipseMath.HUD_BAR_WIDTH, 5, false)
        self.isPositioned = true
    end

    for i = 1, 6 do
        local frame = self.runeFrames[i]
        if frame then
            local runeState = t.runeStates[i]
            if runeState then
                frame:Show()
                if runeState.ready then
                    -- Bright rune
                    if frame.texture then
                        frame.texture:SetVertexColor(1, 1, 1)
                    end
                    if frame.textFieldTime then
                        frame.textFieldTime:DSetText("")
                    end
                else
                    -- On cooldown - dim and show remaining time
                    if frame.texture then
                        frame.texture:SetVertexColor(0.4, 0.4, 0.4)
                    end
                    if frame.textFieldTime then
                        local remaining = runeState.start + runeState.duration - GetTime()
                        if remaining > 0 then
                            frame.textFieldTime:DSetText(string.format("%.0f", remaining))
                        else
                            frame.textFieldTime:DSetText("")
                        end
                    end
                end
            else
                frame:Hide()
            end
        end
    end
end
