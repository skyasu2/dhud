local ADDON_NAME, ns = ...

local bootFrame = ns.CreateEventFrame()
bootFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local initialized = false

function bootFrame:PLAYER_ENTERING_WORLD()
    if initialized then return end
    initialized = true

    -- Initialize settings from SavedVariables
    ns.Settings:Init()

    -- Initialize state tracker (OnUpdate timer, combat/target/vehicle/etc)
    ns.TrackerHelper:Init()

    -- Create frame hierarchy
    ns.Layout:CreateFrames()

    -- Wire up trackers, renderers, and slots
    ns.HUDManager:Init()

    -- Initialize alpha state machine
    ns.AlphaManager:Init()

    ns.Print("v1.0.1 loaded. /dhudlite for commands.")
end

-- Slash commands
SLASH_DHUDLITE1 = "/dhudlite"
SLASH_DHUDLITE2 = "/dhud"
SlashCmdList["DHUDLITE"] = function(msg)
    -- Use WoW API helpers; Lua strings have no :trim()
    msg = strlower(strtrim(msg or ""))

    if msg == "reset" then
        DHUDLITE_DB = nil
        ns.Settings:Init()
        ReloadUI()
    elseif msg == "show" then
        ns.AlphaManager:ForceAlpha(1.0)
        ns.Print("Forced visible.")
    elseif msg == "hide" then
        ns.AlphaManager:ForceAlpha(0)
        ns.Print("Hidden.")
    elseif msg == "alpha" then
        ns.AlphaManager:Refresh()
        ns.Print("Alpha refreshed.")
    elseif msg:match("^distance ") then
        local n = tonumber((msg:match("^distance%s+(%S+)")))
        if n then
            ns.Settings:Set("barsDistanceDiv2", n)
            ns.Layout:SetBarsDistance(n)
            ns.Print("Bars half-distance set to: " .. n)
        else
            ns.Print("Usage: /dhudlite distance <number>")
        end
    elseif msg:match("^style ") then
        local n = tonumber((msg:match("^style%s+(%S+)")))
        if n and n >= 1 and n <= 5 then
            ns.Settings:Set("barsTexture", n)
            ns.Layout:RefreshBarStyles()
            ns.Print("Bar style set to: " .. n)
        else
            ns.Print("Usage: /dhudlite style <1-5>")
        end
    elseif msg:match("^bg ") then
        local arg = msg:match("^bg%s+(%S+)") or ""
        if arg == "on" or arg == "off" then
            local v = (arg == "on")
            ns.Settings:Set("showBackground", v)
            if ns.Layout and ns.Layout.RefreshBackgrounds then ns.Layout:RefreshBackgrounds() end
            ns.Print("Background mask: " .. (v and "on" or "off"))
        else
            ns.Print("Usage: /dhudlite bg <on|off>")
        end
    elseif msg:match("^castfreq ") then
        local arg = msg:match("^castfreq%s+(%S+)") or ""
        if arg == "semi" or arg == "normal" then
            ns.Settings:Set("castUpdateRate", arg)
            ns.Print("Cast update rate set to: " .. arg)
        else
            ns.Print("Usage: /dhudlite castfreq <semi|normal>")
        end
    elseif msg == "debug" then
        local hp, hpmax = UnitHealth("player"), UnitHealthMax("player")
        local ptype = UnitPowerType("player")
        local pp, ppmax = UnitPower("player", ptype), UnitPowerMax("player", ptype)
        ns.Print(string.format("HP %d/%d (%.1f%%)", hp or 0, hpmax or 0, (hpmax and hp and hpmax>0) and (hp*100.0/hpmax) or 0))
        ns.Print(string.format("Power type %s val %d/%d", tostring(ptype), pp or 0, ppmax or 0))
        ns.Print(string.format("Distance %d, Style %d, BG %s", ns.Settings:Get("barsDistanceDiv2") or 0, ns.Settings:Get("barsTexture") or 1, tostring(ns.Settings:Get("showBackground"))))
    else
        ns.Print("Commands:")
        ns.Print("  /dhudlite reset - Reset all settings and reload")
        ns.Print("  /dhudlite show - Force HUD visible")
        ns.Print("  /dhudlite hide - Hide HUD")
        ns.Print("  /dhudlite alpha - Refresh alpha state")
        ns.Print("  /dhudlite bg <on|off> - Toggle background mask")
        ns.Print("  /dhudlite distance <num> - Set half-distance between bars")
        ns.Print("  /dhudlite style <1-5> - Set bar texture style")
        ns.Print("  /dhudlite castfreq <semi|normal> - Set cast update rate")
        ns.Print("  /dhudlite debug - Print quick diagnostics")
    end
end
