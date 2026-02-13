local ADDON_NAME, ns = ...

local TextFormat = {}
ns.TextFormat = TextFormat

-- Use uppercase suffixes consistently: K (thousand), M (million), G (billion), T (trillion)
local METRIC_PREFIXES = { "K", "M", "G", "T" }

function TextFormat:FormatNumber(number, limit)
    if not number then return "0" end
    local isSecret = issecretvalue and issecretvalue(number)
    -- For secret values, use Blizzard's C++ AbbreviateNumbers (handles secrets natively)
    if isSecret then
        if AbbreviateNumbers and ns.Settings:Get("shortNumbers") then
            return AbbreviateNumbers(number)
        end
        return string.format("%s", number)
    end
    limit = limit or (ns.Settings:Get("shortNumbers") and 3 or 1000)
    if number == 0 then return "0" end
    local numChars = math.floor(math.log10(math.abs(number)) + 1)
    if numChars <= limit then
        return string.format("%d", number)
    end
    local overLimit = numChars - limit
    local prefixIdx = math.floor((overLimit + 2) / 3)
    local divideBy = 10 ^ (prefixIdx * 3)
    local prefix = METRIC_PREFIXES[prefixIdx] or ""
    local shortened = math.floor(number / divideBy * 10 + 0.5) / 10
    -- Drop decimal if it's .0 (e.g. 15.0k → 15k)
    if shortened == math.floor(shortened) then
        return string.format("%d%s", shortened, prefix)
    end
    return string.format("%.1f%s", shortened, prefix)
end

function TextFormat:FormatTime(secs)
    if secs >= 86400 then
        return string.format("%dd", math.floor(secs / 86400 + 0.5))
    elseif secs >= 3600 then
        return string.format("%dh", math.floor(secs / 3600 + 0.5))
    elseif secs >= 99 then
        return string.format("%dm", math.floor(secs / 60 + 0.5))
    elseif secs >= 10 then
        return string.format("%d", math.floor(secs + 0.5))
    else
        return string.format("%.1f", secs)
    end
end

-- Format health/power text using string.format (Secret Value safe)
function TextFormat:FormatHealthText(tracker)
    return string.format("%s / %s",
        self:FormatNumber(tracker.amount),
        self:FormatNumber(tracker.amountMax))
end

function TextFormat:FormatPowerText(tracker)
    return string.format("%s / %s",
        self:FormatNumber(tracker.amount),
        self:FormatNumber(tracker.amountMax))
end

function TextFormat:FormatPercent(current, maximum)
    -- Secret values can't do arithmetic
    if issecretvalue and (issecretvalue(current) or issecretvalue(maximum)) then
        return ""
    end
    if maximum <= 0 then return "0%" end
    return string.format("%d%%", math.floor(current * 100 / maximum))
end

-- Get accessible percentage via Blizzard API (CurveConstants.ScaleTo100 → 0-100)
local function _getSecretPercent(kind, tracker)
    if not CurveConstants then return nil end
    if kind == "textFormatHealth" and UnitHealthPercent then
        return UnitHealthPercent(tracker.unitId, true, CurveConstants.ScaleTo100)
    elseif kind == "textFormatPower" and UnitPowerPercent then
        return UnitPowerPercent(tracker.unitId, tracker.resourceType, true, CurveConstants.ScaleTo100)
    end
    return nil
end

-- Build percent suffix: "VALUE(|cffffffffPCT%|r)"
local function _pctSuffix(kind, tracker, cur, max)
    local isSecret = issecretvalue and (issecretvalue(cur) or issecretvalue(max))
    local pctStr
    if isSecret then
        local p = _getSecretPercent(kind, tracker)
        if p then pctStr = string.format("%.0f%%", p) end
    elseif max > 0 then
        pctStr = string.format("%d%%", math.floor(cur * 100 / max))
    else
        pctStr = "0%"
    end
    if pctStr then
        return "|cffffffff(" .. pctStr .. ")|r"
    end
    return ""
end

-- Reconstruct a non-secret approximation of a secret amount using percent * max.
-- Returns the original value unchanged when reconstruction is not possible.
local function _resolveSecretAmount(kind, tracker)
    local cur = tracker.amount or 0
    if not (issecretvalue and issecretvalue(cur)) then return cur end
    local max = tracker.amountMax or 0
    if issecretvalue and issecretvalue(max) then return cur end
    if max <= 0 then return cur end
    local pct = _getSecretPercent(kind, tracker)
    if not pct then return cur end
    if issecretvalue and issecretvalue(pct) then return cur end
    return math.floor(max * pct / 100 + 0.5)
end

-- Value formatter: combined "VALUE(PCT%)" for textField
local function _formatValue(kind, tracker)
    local fmt = ns.Settings:Get(kind) or "value+percent"
    local cur = tracker.amount or 0
    local max = tracker.amountMax or 0

    if fmt == "none" then return "" end

    if fmt == "deficit" then
        local rCur = _resolveSecretAmount(kind, tracker)
        local rMax = max
        if issecretvalue and (issecretvalue(rCur) or issecretvalue(rMax)) then return "" end
        local deficit = rMax - rCur
        if deficit <= 0 then return "" end
        return "-" .. TextFormat:FormatNumber(deficit)
    end

    if fmt == "percent" then return "" end

    local resolved = _resolveSecretAmount(kind, tracker)

    if fmt == "value" then
        return TextFormat:FormatNumber(resolved)
    end

    -- "value+percent": "VALUE(PCT%)"
    return TextFormat:FormatNumber(resolved) .. _pctSuffix(kind, tracker, cur, max)
end

-- Percent formatter: only used for "percent" mode (standalone)
local function _formatPercent(kind, tracker)
    local fmt = ns.Settings:Get(kind) or "value+percent"

    if fmt ~= "percent" then return "" end

    local cur = tracker.amount or 0
    local max = tracker.amountMax or 0

    if issecretvalue and (issecretvalue(cur) or issecretvalue(max)) then
        local pct = _getSecretPercent(kind, tracker)
        if pct then return string.format("|cffffffff(%.0f%%)|r", pct) end
        return ""
    end

    if max <= 0 then return "|cffffffff(0%)|r" end
    return string.format("|cffffffff(%d%%)|r", math.floor(cur * 100 / max))
end

function TextFormat:FormatHealthValue(t) return _formatValue("textFormatHealth", t) end
function TextFormat:FormatHealthPct(t)   return _formatPercent("textFormatHealth", t) end
function TextFormat:FormatPowerValue(t)  return _formatValue("textFormatPower", t) end
function TextFormat:FormatPowerPct(t)    return _formatPercent("textFormatPower", t) end

