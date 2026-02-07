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
    elseif msg:match("^visible ") then
        local arg = msg:match("^visible%s+(%S+)") or ""
        if arg == "on" then
            ns.AlphaManager:ForceAlpha(1.0)
            ns.Print("Visible: on")
        elseif arg == "off" then
            ns.AlphaManager:ForceAlpha(0)
            ns.Print("Visible: off")
        else
            ns.Print("Usage: /dhudlite visible <on|off>")
        end
    elseif msg:match("^move") then
        local arg = msg:match("^move%s+(%S+)")
        if arg == "on" then
            ns.Layout:SetMovable(true)
            ns.Print("Move mode: on")
        elseif arg == "off" then
            ns.Layout:SetMovable(false)
            ns.Print("Move mode: off")
        else
            ns.Print("Usage: /dhudlite move <on|off>")
        end
    elseif msg == "options" or msg == "opt" then
        if ns.OpenOptions then ns.OpenOptions() else ns.Print("Open Options -> AddOns manually.") end
    else
        ns.Print("Commands:")
        ns.Print("  /dhudlite options - Open options panel")
        ns.Print("  /dhudlite move <on|off> - Toggle move mode")
        ns.Print("  /dhudlite visible <on|off> - Force HUD visible/hidden")
        ns.Print("  /dhudlite reset - Reset all settings and reload")
    end
end
