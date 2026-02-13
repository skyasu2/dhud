local ADDON_NAME, ns = ...

local EllipseMath = {}
ns.EllipseMath = EllipseMath

-- Default ellipse parameters matching DHUD textures
EllipseMath.HUD_RADIUS_X = 336
EllipseMath.HUD_RADIUS_Y = 336
EllipseMath.HUD_RADIUS_X_OUTOFIMAGE = 280
EllipseMath.HUD_ANGLE_ARC = 20.2
EllipseMath.HUD_BAR_WIDTH = 14.5
EllipseMath.HUD_SMALLBAR_WIDTH = 12

local radiusX = EllipseMath.HUD_RADIUS_X
local radiusY = EllipseMath.HUD_RADIUS_Y
local angleArc = EllipseMath.HUD_ANGLE_ARC

local cos = math.cos
local sin = math.sin
local atan = math.atan
local floor = math.floor
local sqrt = math.sqrt
local pi = math.pi

-- Convert degrees to radians for trig
local function rad(deg)
    return deg * pi / 180
end

function EllipseMath:SetDefaultEllipse()
    radiusX = self.HUD_RADIUS_X
    radiusY = self.HUD_RADIUS_Y
    angleArc = self.HUD_ANGLE_ARC
end

function EllipseMath:ScaleEllipse(scale)
    radiusX = radiusX * scale
    radiusY = radiusY * scale
    angleArc = self.HUD_ANGLE_ARC + 10 * (radiusX - self.HUD_RADIUS_X) / self.HUD_RADIUS_X
end

function EllipseMath:CalculatePosition(angleDeg)
    local x = radiusX * cos(rad(angleDeg))
    local y = radiusY * sin(rad(angleDeg))
    return x, y
end

-- Used for LEFT side positioning
function EllipseMath:CalculateAddonPosition(angleDeg)
    local x, y = self:CalculatePosition(angleDeg)
    local dist = ns.Settings:Get("barsDistanceDiv2") or 0
    -- Standard DHUD calculation for left side, adjusted for dist
    x = x - self.HUD_RADIUS_X_OUTOFIMAGE - dist
    -- If x is naturally positive (336-280=56), it means 56px RIGHT of center.
    -- But this is for Left side?
    -- Actually DHUD logic: radiusX=336. x=336.
    -- Left bar texture is at x = -dist-128 to -dist.
    -- If x=56, to put it on left, we usually negate it.
    -- But this function is just helper.
    return floor(x), floor(y)
end

function EllipseMath:CalculateAngleStep(elementRadius)
    local tanAngleDiv4 = elementRadius / (radiusY * 2)
    return atan(tanAngleDiv4) * 4 * 180 / pi
end

function EllipseMath:GetAngleArc()
    return angleArc
end

function EllipseMath:GetArcHeight()
    return sin(rad(angleArc)) * radiusY * 2
end

-- Position combo/resource frames along the ellipse arc
-- isLeft: true for left side, false for right side
-- barWidthOffset: offset from bar edge
-- additionalOffset: extra offset
-- centerBias: vertical center bias as ratio of angleArc (-1.0~1.0, negative = lower, default 0)
function EllipseMath:PositionFramesAlongArc(frames, count, elementSize, scale, barWidthOffset, additionalOffset, isLeft, centerBias)
    self:SetDefaultEllipse()
    if scale and scale ~= 1 then
        self:ScaleEllipse(scale)
    end

    local halfSize = elementSize / 2
    local angleStep = self:CalculateAngleStep(halfSize)
    -- Center N elements around bias-derived angle within the arc
    local totalSpan = (count - 1) * angleStep
    if totalSpan > angleArc * 2 then totalSpan = angleArc * 2 end
    local center = centerBias and (angleArc * centerBias) or 0
    local startAngle = center - (totalSpan / 2)
    -- Clamp so elements stay within arc bounds
    if startAngle < -angleArc then startAngle = -angleArc end
    local endAngle = startAngle + totalSpan
    if endAngle > angleArc then
        startAngle = startAngle - (endAngle - angleArc)
        if startAngle < -angleArc then startAngle = -angleArc end
    end

    for i = 1, count do
        local frame = frames[i]
        if frame then
            -- Note: 'angle' assumes standard trig circle where 0 is East.
            local angle = startAngle + (i - 1) * angleStep
            if angle > angleArc then angle = angleArc end

            local x, y
            -- Base position on circle
            -- x = ~336, y = -100 to +100
            local baseX, baseY = self:CalculatePosition(angle)
            
            local dist = ns.Settings:Get("barsDistanceDiv2") or 0
            
            -- We want to position relative to the INNER edge of the bar?
            -- Bar width = 128.
            -- Inner edge is at +/- dist.
            -- Outer edge is at +/- (dist + 128).
            
            -- Legacy logic: x = 336. radius-outofimage = 56.
            -- 56 is the 'visual' x-offset of the arc from the vertical line?
            -- If we want to attach to the bar.
            
            if isLeft then
                 -- Left Side: Negative X.
                 -- Bar is at [-dist-128, -dist].
                 -- We want bubble at ~ (-dist - 56 - offsets).
                 -- My derived offset from legacy code was 56.
                 local offsetX = baseX - self.HUD_RADIUS_X_OUTOFIMAGE -- ~56
                 x = - (dist + offsetX + (barWidthOffset or 0) + (additionalOffset or 0))
                 y = baseY
            else
                 -- Right Side: Positive X.
                 -- Bar is at [dist, dist+128].
                 -- We want bubble at ~ (dist + 56 + offsets).
                 local offsetX = baseX - self.HUD_RADIUS_X_OUTOFIMAGE -- ~56
                 x = (dist + offsetX + (barWidthOffset or 0) + (additionalOffset or 0))
                 y = baseY
            end
            
            frame:ClearAllPoints()
            -- Parent is DHUDLITE_UIParent (CENTER, CENTER)
            frame:SetPoint("CENTER", frame:GetParent(), "CENTER", floor(x), floor(y))
        end
    end
end
