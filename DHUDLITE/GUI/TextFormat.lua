local ADDON_NAME, ns = ...

local TextFormat = {}
ns.TextFormat = TextFormat

local METRIC_PREFIXES = { "k", "M", "G", "T" }

function TextFormat:FormatNumber(number, limit)
    limit = limit or (ns.Settings:Get("shortNumbers") and 5 or 1000)
    if number == 0 then return "0" end
    if issecretvalue and issecretvalue(number) then
        return string.format("%s", number)
    end
    local numChars = math.floor(math.log10(math.abs(number)) + 1)
    if numChars <= limit then
        return string.format("%d", number)
    end
    local overLimit = numChars - limit
    local prefixIdx = math.floor((overLimit + 2) / 3)
    local divideBy = 10 ^ (prefixIdx * 3)
    local prefix = METRIC_PREFIXES[prefixIdx] or ""
    return string.format("%d%s", math.floor(number / divideBy + 0.5), prefix)
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
    if maximum <= 0 then return "0%" end
    return string.format("%d%%", math.floor(current * 100 / maximum))
end

-- IceHUD-like flexible text formats
local function format_by_key(kind, tracker)
    local fmt = ns.Settings:Get(kind) or "value+percent"
    local cur = tracker.amount or 0
    local max = tracker.amountMax or 0
    if fmt == "none" then
        return ""
    elseif fmt == "value" then
        return TextFormat:FormatNumber(cur)
    elseif fmt == "percent" then
        return TextFormat:FormatPercent(cur, max)
    elseif fmt == "value+percent" then
        return string.format("%s (%s)", TextFormat:FormatNumber(cur), TextFormat:FormatPercent(cur, max))
    elseif fmt == "deficit" then
        local deficit = max - cur
        if deficit <= 0 then return "" end
        return string.format("-%s", TextFormat:FormatNumber(deficit))
    end
    return string.format("%s / %s", TextFormat:FormatNumber(cur), TextFormat:FormatNumber(max))
end

function TextFormat:FormatHealthTextBySetting(tracker)
    return format_by_key("textFormatHealth", tracker)
end

function TextFormat:FormatPowerTextBySetting(tracker)
    return format_by_key("textFormatPower", tracker)
end

function TextFormat:FormatCastTime(remaining)
    if remaining <= 0 then return "" end
    return string.format("%.1f", remaining)
end

function TextFormat:GetShortName(name)
    if not name then return "" end
    local idx = name:find("%-")
    if idx then
        return name:sub(1, idx - 1)
    end
    return name
end
