local ADDON_NAME, ns = ...

local ResourceSlot = ns.CreateClass(ns.SlotBase, {})
ns.ResourceSlot = ResourceSlot

local Colorize = ns.Colorize
local Textures = ns.Textures
local EllipseMath = ns.EllipseMath

-- Per-resourceType color textures (original DHUD patterns)
local RESOURCE_COLORS = {
    -- Rogue/Druid: red(1-3) → orange(4) → green(5) → purple(6-8) → cyan(9-10)
    COMBO = {
        "ComboCircleRed", "ComboCircleRed", "ComboCircleRed",
        "ComboCircleOrange",
        "ComboCircleGreen",
        "ComboCirclePurple", "ComboCirclePurple", "ComboCirclePurple",
        "ComboCircleCyan", "ComboCircleCyan",
    },
    -- Paladin: red → orange → green
    HOLY_POWER = {
        "ComboCircleRed", "ComboCircleOrange", "ComboCircleGreen",
        "ComboCircleGreen", "ComboCircleGreen",
    },
    -- Monk: all jade green
    CHI = {
        "ComboCircleJadeGreen", "ComboCircleJadeGreen",
        "ComboCircleJadeGreen", "ComboCircleJadeGreen",
        "ComboCircleJadeGreen", "ComboCircleJadeGreen",
    },
    -- Warlock: all purple
    SOUL_SHARDS = {
        "ComboCirclePurple", "ComboCirclePurple", "ComboCirclePurple",
        "ComboCirclePurple", "ComboCirclePurple",
    },
    -- Mage: all cyan
    ARCANE_CHARGES = {
        "ComboCircleCyan", "ComboCircleCyan",
        "ComboCircleCyan", "ComboCircleCyan",
    },
    -- Evoker: all cyan
    ESSENCE = {
        "ComboCircleCyan", "ComboCircleCyan", "ComboCircleCyan",
        "ComboCircleCyan", "ComboCircleCyan",
    },
}

function ResourceSlot:New()
    local o = ResourceSlot.super.New(self)
    o.comboFrames = nil
    o.runeFrames = nil
    o.lastCount = 0
    o.lastCountMax = 0
    o.isPositioned = false
    o.runeTickSubscribed = false
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
    ns.Settings:OnChange("barsDistanceDiv2", self, function()
        self.isPositioned = false
        self:OnDataChanged()
    end)
end

function ResourceSlot:Deactivate()
    ns.Settings:OffChange("barsDistanceDiv2", self)
    if self.tracker then
        self.tracker:StopTracking()
    end
    self:UnsubscribeRuneTick()
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
        -- Place combo/resource bubbles on the right side, biased toward the lower half
        EllipseMath:PositionFramesAlongArc(self.comboFrames, countMax, 20, scale,
            EllipseMath.HUD_BAR_WIDTH, 18, false, -0.4)
        self.isPositioned = true
    end

    -- Show/hide frames
    for i = 1, countMax do
        local frame = self.comboFrames[i]
        if frame then
            if i <= count then
                -- Set color based on resource type and position
                local colors = RESOURCE_COLORS[self.tracker.resourceType] or RESOURCE_COLORS.COMBO
                local colorIdx = ((i - 1) % #colors) + 1
                local texName = colors[colorIdx]
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
        -- Place runes on the right side, biased toward the lower half
        EllipseMath:PositionFramesAlongArc(self.runeFrames, 6, 30, scale,
            EllipseMath.HUD_BAR_WIDTH, 18, false, -0.4)
        self.isPositioned = true
    end

    local anyOnCooldown = false
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
                    anyOnCooldown = true
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

    -- Subscribe to frequent updates while any rune is on cooldown
    if anyOnCooldown then
        self:SubscribeRuneTick()
    else
        self:UnsubscribeRuneTick()
    end
end

function ResourceSlot:SubscribeRuneTick()
    if self.runeTickSubscribed then return end
    self.runeTickSubscribed = true
    ns.TrackerHelper.events:On("UpdateSemiFrequent", self, self.OnRuneTick)
end

function ResourceSlot:UnsubscribeRuneTick()
    if not self.runeTickSubscribed then return end
    self.runeTickSubscribed = false
    ns.TrackerHelper.events:Off("UpdateSemiFrequent", self, self.OnRuneTick)
end

function ResourceSlot:OnRuneTick()
    if not self.isActive or not self.tracker then return end
    self:UpdateRunes()
end
