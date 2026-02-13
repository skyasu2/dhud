local ADDON_NAME, ns = ...

local Colorize = {}
ns.Colorize = Colorize

function Colorize:GetHealthColor(pct, unitId)
    -- Blizzard standard gradient: red (0%) -> yellow (50%) -> green (100%)
    if pct <= 0.5 then
        return 1, pct * 2, 0
    else
        return 1 - (pct - 0.5) * 2, 1, 0
    end
end

function Colorize:GetHealthLayerColor(layerType, unitId)
    if layerType == "shield" then    return 1.00, 1.00, 0.53
    elseif layerType == "absorb" then return 1.00, 0.27, 0.27
    elseif layerType == "reduce" then return 0.53, 0.27, 0.27
    elseif layerType == "heal" then   return 0.27, 1.00, 0.27
    elseif layerType == "notTapped" then return 0.53, 0.53, 0.53
    end
    return 1, 1, 1
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
    if not c then return 1, 1, 1 end
    return c.r, c.g, c.b
end

function Colorize:ColorizeString(text, r, g, b)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end
