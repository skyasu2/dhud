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

    ns.Print("v1.0.0 loaded. /dhudlite for commands.")
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
    else
        ns.Print("Commands:")
        ns.Print("  /dhudlite reset - Reset all settings and reload")
        ns.Print("  /dhudlite show - Force HUD visible")
        ns.Print("  /dhudlite hide - Hide HUD")
        ns.Print("  /dhudlite alpha - Refresh alpha state")
    end
end
