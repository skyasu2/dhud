local ADDON_NAME, ns = ...

local Colorize = {}
ns.Colorize = Colorize

-- Reusable scratch tables for gradient calculations (avoid per-frame allocation)
local _c1 = { 0, 0, 0 }
local _c2 = { 0, 0, 0 }
local _c3 = { 0, 0, 0 }

function Colorize:HexToRGB(hex)
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return r, g, b
end

function Colorize:Lerp(pct, c0, c1)
    if pct >= 1 then return c1[1], c1[2], c1[3] end
    if pct <= 0 then return c0[1], c0[2], c0[3] end
    return c0[1] + (c1[1] - c0[1]) * pct,
           c0[2] + (c1[2] - c0[2]) * pct,
           c0[3] + (c1[3] - c0[3]) * pct
end

function Colorize:GetHealthColor(pct, unitId)
    local key = (unitId == "player") and "colorPlayerHealth"
                or (unitId == "pet") and "colorPetHealth"
                or "colorTargetHealth"
    local hexTable = ns.Settings:Get(key)
    if not hexTable or #hexTable == 0 then return 0, 1, 0 end
    if #hexTable == 1 then
        return self:HexToRGB(hexTable[1])
    end
    -- 3-color gradient: red (0%) -> yellow (50%) -> green (100%)
    if #hexTable >= 3 then
        _c1[1], _c1[2], _c1[3] = self:HexToRGB(hexTable[3]) -- low HP
        _c2[1], _c2[2], _c2[3] = self:HexToRGB(hexTable[2]) -- mid HP
        _c3[1], _c3[2], _c3[3] = self:HexToRGB(hexTable[1]) -- full HP
        if pct <= 0.5 then
            return self:Lerp(pct / 0.5, _c1, _c2)
        else
            return self:Lerp((pct - 0.5) / 0.5, _c2, _c3)
        end
    end
    -- 2-color gradient
    _c1[1], _c1[2], _c1[3] = self:HexToRGB(hexTable[2])
    _c2[1], _c2[2], _c2[3] = self:HexToRGB(hexTable[1])
    return self:Lerp(pct, _c1, _c2)
end

function Colorize:GetHealthLayerColor(layerType, unitId)
    local key
    if layerType == "shield" then
        key = "colorHealthShield"
    elseif layerType == "absorb" then
        key = "colorHealthAbsorb"
    elseif layerType == "reduce" then
        key = "colorHealthReduce"
    elseif layerType == "heal" then
        key = "colorHealthHeal"
    elseif layerType == "notTapped" then
        key = "colorHealthNotTapped"
    else
        return 1, 1, 1
    end
    local hexTable = ns.Settings:Get(key)
    if not hexTable or #hexTable == 0 then return 1, 1, 1 end
    return self:HexToRGB(hexTable[1])
end

function Colorize:GetPowerColor(powerType, unitId)
    -- WoW API 직접 사용 (패치 자동 대응, 새 자원 타입 자동 지원)
    -- 1. C_PowerBarColor (11.0+ 권장 API)
    if _G.C_PowerBarColor and _G.C_PowerBarColor.GetPowerBarColor then
        local c = _G.C_PowerBarColor.GetPowerBarColor(powerType)
        if c and type(c) == "table" and c.r then return c.r, c.g, c.b end
    end
    -- 2. GetPowerBarColor with token (가장 신뢰)
    if _G.GetPowerBarColor then
        local _, token = UnitPowerType(unitId or "player")
        if token then
            local r, g, b = _G.GetPowerBarColor(token)
            if r and g and b then return r, g, b end
        end
        -- 3. GetPowerBarColor with numeric ID
        local r, g, b = _G.GetPowerBarColor(powerType)
        if r and g and b then return r, g, b end
    end
    -- 4. Global table 폴백
    if _G.PowerBarColor then
        local info = _G.PowerBarColor[powerType]
        if info then return info.r or 1, info.g or 1, info.b or 1 end
    end
    return 1, 1, 1
end

function Colorize:GetCastColor(state, unitId)
    local CT = ns.CastTracker
    local key
    if state == CT.STATE_CASTING then
        key = "colorCastCast"
    elseif state == CT.STATE_CHANNELING then
        key = "colorCastChannel"
    elseif state == CT.STATE_EMPOWERING then
        key = "colorCastCast"
    elseif state == CT.STATE_INTERRUPTED then
        key = "colorCastInterrupted"
    elseif state == CT.STATE_SUCCEEDED then
        key = "colorCastCast"
    else
        return 1, 1, 0
    end
    local hexTable = ns.Settings:Get(key)
    if hexTable and #hexTable > 0 then
        return self:HexToRGB(hexTable[1])
    end
    return 1, 1, 0
end

function Colorize:GetClassColor(classToken)
    -- C_ClassColor API 우선 (10.0+)
    if _G.C_ClassColor and _G.C_ClassColor.GetClassColor then
        local color = _G.C_ClassColor.GetClassColor(classToken)
        if color then return color.r, color.g, color.b end
    end
    -- 글로벌 테이블 폴백
    if RAID_CLASS_COLORS then
        local colors = RAID_CLASS_COLORS[classToken]
        if colors then return colors.r, colors.g, colors.b end
    end
    return 1, 1, 1
end

function Colorize:GetDifficultyColor(level)
    if level < 0 then level = 256 end
    local c = GetQuestDifficultyColor(level)
    return c.r, c.g, c.b
end

function Colorize:RGBToHex(r, g, b)
    return string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

function Colorize:ColorizeString(text, r, g, b)
    return string.format("|cff%s%s|r", self:RGBToHex(r, g, b), text)
end
