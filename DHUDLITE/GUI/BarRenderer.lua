local ADDON_NAME, ns = ...

local BarRenderer = ns.CreateClass(nil, {})
ns.BarRenderer = BarRenderer

-- Animation speeds
local ANIM_SPEED_FAST = 1.0
local ANIM_SPEED_SLOW = 0.25

function BarRenderer:New(group, clippingId, side)
    local o = setmetatable({}, self)
    o.group = group
    o.side = side -- "left" or "right"
    o.isAnimating = false
    o.processingUpdates = false
    o.timeUpdatedAt = 0

    -- Clipping info
    local clip = ns.Textures:GetClipping(clippingId)
    local texInfo = ns.Textures.list[clippingId]
    o.pixelsHeight = clip[1]
    o.fromTopPct = clip[2] / clip[1]
    o.fromBotPct = clip[3] / clip[1]
    o.realHeightPct = (clip[1] - clip[2] - clip[3]) / clip[1]
    -- Texture X coords: left side = normal, right side = mirrored
    if side == "left" then
        o.texX1 = texInfo[2]
        o.texX2 = texInfo[3]
    else
        o.texX1 = texInfo[3]
        o.texX2 = texInfo[2]
    end

    -- Animation state arrays
    o.valuesInfo = {}       -- { { type, priority }, ... }
    o.currentAnim = {}      -- current bar heights
    o.targetAnim = {}       -- target bar heights
    o.sigHeightCurrent = 1
    o.sigHeightTarget = 1
    o.animate = true

    -- Secret value support: create StatusBar + fill curves (IceHUD pattern)
    o.isSecretEnv = (issecretvalue ~= nil)
    if o.isSecretEnv and C_CurveUtil then
        -- Fill curve: maps health/power 0-1 to StatusBar value accounting for texture margins
        o.fillCurve = C_CurveUtil.CreateCurve()
        o.fillCurve:SetType(Enum.LuaCurveType.Linear)
        o.fillCurve:ClearPoints()
        o.fillCurve:AddPoint(0, o.fromBotPct)
        o.fillCurve:AddPoint(1, 1 - o.fromTopPct)

        -- Health color curves (IceHUD pattern: R/G/B via UnitHealthPercent)
        -- Red: 1 at 0% → 1 at 50% → 0 at 100%
        o.hpColorCurveR = C_CurveUtil.CreateCurve()
        o.hpColorCurveR:SetType(Enum.LuaCurveType.Linear)
        o.hpColorCurveR:ClearPoints()
        o.hpColorCurveR:AddPoint(0, 1)
        o.hpColorCurveR:AddPoint(0.5, 1)
        o.hpColorCurveR:AddPoint(1, 0)

        -- Green: 0 at 0% → 1 at 50% → 1 at 100%
        o.hpColorCurveG = C_CurveUtil.CreateCurve()
        o.hpColorCurveG:SetType(Enum.LuaCurveType.Linear)
        o.hpColorCurveG:ClearPoints()
        o.hpColorCurveG:AddPoint(0, 0)
        o.hpColorCurveG:AddPoint(0.5, 1)
        o.hpColorCurveG:AddPoint(1, 1)
    end

    return o
end

function BarRenderer:SetParentFrame(parentFrame)
    self.parentFrame = parentFrame
end

-- Lazily create StatusBar overlay on group[1] for secret value rendering
function BarRenderer:EnsureStatusBar()
    if self.statusBar then return self.statusBar end

    local frame = self.group[1]
    if not frame then return nil end

    local sb = CreateFrame("StatusBar", nil, frame)
    sb:SetAllPoints(frame)
    sb:SetMinMaxValues(0, 1)
    sb:SetOrientation("VERTICAL")
    sb:SetFillStyle("STANDARD")
    sb:SetFrameLevel(frame:GetFrameLevel() + 1)

    -- Use the same bar texture
    local tex = sb:CreateTexture(nil, "ARTWORK")
    local style = ns.Settings:Get("barsTexture") or 1
    local pathPrefix = frame.texture and frame.texture.pathPrefix
    if pathPrefix then
        local path = ns.FrameFactory.ResolvePath(pathPrefix .. tostring(style))
        tex:SetTexture(path)
    end
    if not tex:GetTexture() then
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    sb:SetStatusBarTexture(tex)

    -- Mirror for right side via tex coords (StatusBar respects initial X coords)
    if self.side == "right" then
        tex:SetTexCoord(1, 0, 0, 1)
    end

    sb.barTexture = tex
    self.statusBar = sb
    return sb
end

-- Secret value rendering: pass fill value directly to StatusBar (IceHUD pattern)
function BarRenderer:UpdateBarSecret(fillValue, r, g, b)
    local sb = self:EnsureStatusBar()
    if not sb then return end

    -- Show the group frame
    self.group:SetFramesShown(1)
    sb:Show()

    -- Hide original texture so StatusBar is visible
    local frame = self.group[1]
    if frame and frame.texture then
        frame.texture:SetAlpha(0)
    end

    -- Set fill (secret value goes directly to SetValue - WoW engine handles it)
    if fillValue then
        sb:SetValue(fillValue)
    else
        sb:SetValue(0)
    end

    -- Set color
    if r then
        sb:SetStatusBarColor(r, g, b)
    end
end

function BarRenderer:HideBar()
    self.isAnimating = false
    self:SetUpdatesRequired(false)
    self.group:SetFramesShown(0)
    if self.statusBar then
        self.statusBar:Hide()
    end
end

-- Standard (non-secret) rendering below --

function BarRenderer:UpdateSegment(index, heightBegin, heightEnd, r, g, b)
    local frame = self.group[index]
    if not frame then return end
    local tex = frame.texture
    if not tex then return end

    local h = self.realHeightPct * self.pixelsHeight * (heightEnd - heightBegin)
    if h <= 0 then h = 0.01 end

    local texTop = 1 - self.fromTopPct - (self.realHeightPct * (1 - heightEnd))
    local texBot = self.fromBotPct + (self.realHeightPct * heightBegin)
    local offsetY = self.pixelsHeight * texBot

    tex:SetHeight(h)
    tex:SetTexCoord(self.texX1, self.texX2, 1 - texTop, 1 - texBot)
    tex:ClearAllPoints()
    tex:SetPoint("BOTTOM", self.parentFrame, "BOTTOM", 0, offsetY)
    tex:SetVertexColor(r, g, b)
end

function BarRenderer:UpdateBar(valuesInfo, valuesHeight, heightSignificant, colorFunc)
    -- Copy target state
    local numValues = #valuesInfo
    -- Ensure arrays are the right size
    while #self.valuesInfo < numValues do
        self.valuesInfo[#self.valuesInfo + 1] = valuesInfo[#self.valuesInfo + 1]
        self.currentAnim[#self.currentAnim + 1] = 0
        self.targetAnim[#self.targetAnim + 1] = 0
    end
    while #self.valuesInfo > numValues do
        table.remove(self.valuesInfo)
        table.remove(self.currentAnim)
        table.remove(self.targetAnim)
    end
    for i = 1, numValues do
        self.valuesInfo[i] = valuesInfo[i]
        self.targetAnim[i] = valuesHeight[i]
    end
    self.sigHeightTarget = heightSignificant
    self.colorFunc = colorFunc

    self.animate = ns.Settings:Get("animateBars")
    self.timeUpdatedAt = ns.TrackerHelper.timerMs - 0.016
    self.isAnimating = true
    self:SetUpdatesRequired(true)
    self:OnUpdateTime()
end

function BarRenderer:ForceInstant()
    local saved = self.animate
    self.animate = false
    self:OnUpdateTime()
    self.animate = saved
end

function BarRenderer:SetUpdatesRequired(required)
    if self.processingUpdates == required then return end
    self.processingUpdates = required
    if required then
        ns.TrackerHelper.events:On("UpdateFrequent", self, self.OnUpdateTime)
    else
        ns.TrackerHelper.events:Off("UpdateFrequent", self, self.OnUpdateTime)
    end
end

function BarRenderer:OnUpdateTime()
    if not self.isAnimating then return end

    local timerMs = ns.TrackerHelper.timerMs
    local timeDiff = timerMs - self.timeUpdatedAt
    self.timeUpdatedAt = timerMs

    if not self.animate then
        timeDiff = 10000
    end

    local stepFast = ANIM_SPEED_FAST * timeDiff
    local stepSlow = ANIM_SPEED_SLOW * timeDiff

    self.isAnimating = false
    for i = 1, #self.targetAnim do
        local target = self.targetAnim[i]
        local current = self.currentAnim[i]
        local diff = target - current
        if diff ~= 0 then
            if diff > 0 then
                current = current + (diff > 0.1 and stepFast or stepSlow)
                if current > target then current = target end
            else
                current = current - (diff < -0.1 and stepFast or stepSlow)
                if current < target then current = target end
            end
            self.currentAnim[i] = current
            if current ~= target then
                self.isAnimating = true
            end
        end
    end

    -- Animate significant height
    local sigDiff = self.sigHeightTarget - self.sigHeightCurrent
    if sigDiff ~= 0 then
        if sigDiff > 0 then
            self.sigHeightCurrent = self.sigHeightCurrent + (sigDiff > 0.1 and stepFast or stepSlow)
            if self.sigHeightCurrent > self.sigHeightTarget then self.sigHeightCurrent = self.sigHeightTarget end
        else
            self.sigHeightCurrent = self.sigHeightCurrent - (sigDiff < -0.1 and stepFast or stepSlow)
            if self.sigHeightCurrent < self.sigHeightTarget then self.sigHeightCurrent = self.sigHeightTarget end
        end
    end

    if not self.isAnimating then
        self:SetUpdatesRequired(false)
    end

    self:RenderCurrentState()
end

function BarRenderer:RenderCurrentState()
    local numVisible = 0
    for i = 1, #self.currentAnim do
        if self.currentAnim[i] ~= 0 then
            numVisible = numVisible + 1
        end
    end
    self.group:SetFramesShown(numVisible)

    local idx = 1
    local heightBegin = 0
    for i = 1, #self.currentAnim do
        local v = self.currentAnim[i]
        if v ~= 0 then
            local heightEnd = heightBegin + v
            if heightEnd > 1.0 then heightEnd = 1.0 end
            local r, g, b = 1, 1, 1
            if self.colorFunc then
                local sigH = self.sigHeightCurrent
                if sigH <= 0 then sigH = 1 end
                local cr, cg, cb = self.colorFunc(self.valuesInfo[i], heightBegin / sigH, heightEnd / sigH)
                if cr then r, g, b = cr, cg, cb end
            end
            self:UpdateSegment(idx, heightBegin, heightEnd, r, g, b)
            heightBegin = heightEnd
            idx = idx + 1
        end
    end
end
