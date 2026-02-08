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

function EllipseMath:CalculateAddonPosition(angleDeg)
    local x, y = self:CalculatePosition(angleDeg)
    local dist = ns.Settings:Get("barsDistanceDiv2") or 0
    -- 텍스처 로컬(+128) 대신 화면 중앙 기준으로 변환: dist 오프셋 차감
    x = x - self.HUD_RADIUS_X_OUTOFIMAGE - dist
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
function EllipseMath:PositionFramesAlongArc(frames, count, elementSize, scale, barWidthOffset, additionalOffset, isLeft)
    self:SetDefaultEllipse()
    if scale and scale ~= 1 then
        self:ScaleEllipse(scale)
    end

    local halfSize = elementSize / 2
    local angleStep = self:CalculateAngleStep(halfSize)
    local startAngle = -angleArc + ((angleArc * 2) % angleStep) / 2

    for i = 1, count do
        local frame = frames[i]
        if frame then
            local angle = startAngle + (i - 1) * angleStep
            if angle > angleArc then angle = angleArc end
            local x, y = self:CalculateAddonPosition(angle)
            -- Apply bar width offset
            x = x + (barWidthOffset or 0) + (additionalOffset or 0)
            if not isLeft then
                x = -x
            end
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", frame:GetParent(), "CENTER", x, y)
        end
    end
end
