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

    -- Profile change handlers
    ns.events:On("PreProfileChanged", nil, function()
        ns.HUDManager:DeactivateAll()
        ns.HUDManager:Cleanup()
    end)
    ns.events:On("PostProfileChanged", nil, function()
        ns.HUDManager:Init()
        ns.AlphaManager:Refresh()
        local dist = ns.Settings:Get("barsDistanceDiv2")
        if dist then ns.Layout:SetBarsDistance(dist) end
        ns.Layout:RefreshBarStyles()
        ns.Layout:RefreshBackgrounds()
        if ns.Layout.RefreshFonts then ns.Layout:RefreshFonts() end
    end)

    -- Spec change → auto-switch profile if configured
    ns.TrackerHelper.events:On("SpecChanged", nil, function()
        ns.Settings:OnSpecChanged()
    end)

    -- Save optimization: strip default values before WoW serializes SavedVariables
    bootFrame:RegisterEvent("PLAYER_LOGOUT")

    local profileName = ns.Settings:GetProfileName()
    ns.Print("v1.1.0 loaded. Profile: " .. profileName .. ". /dhudlite for commands.")
end

function bootFrame:PLAYER_LOGOUT()
    ns.Settings:PrepareForSave()
end

-- Slash commands
SLASH_DHUDLITE1 = "/dhudlite"
SLASH_DHUDLITE2 = "/dhud"
SlashCmdList["DHUDLITE"] = function(msg)
    local rawMsg = strtrim(msg or "")
    -- Use WoW API helpers; Lua strings have no :trim()
    msg = strlower(rawMsg)

    if msg == "reset" then
        ns.Settings:ResetProfile()
    elseif msg:match("^profile") then
        -- Use rawMsg to preserve profile name case
        local sub = rawMsg:match("^[Pp]rofile%s+(%S+.*)") or ""
        sub = strtrim(sub)
        local cmd = strlower(sub:match("^(%S+)") or "")
        local arg = strtrim(sub:match("^%S+%s+(.+)") or "")

        if cmd == "list" then
            local list = ns.Settings:GetProfileList()
            local current = ns.Settings:GetProfileName()
            ns.Print("Profiles:")
            for _, name in ipairs(list) do
                local mark = (name == current) and " (active)" or ""
                ns.Print("  " .. name .. mark)
            end
        elseif cmd == "use" and arg ~= "" then
            ns.Settings:SetProfile(arg)
        elseif cmd == "new" and arg ~= "" then
            ns.Settings:CreateProfile(arg)
        elseif cmd == "copy" and arg ~= "" then
            ns.Settings:CopyProfile(arg)
        elseif cmd == "delete" and arg ~= "" then
            ns.Settings:DeleteProfile(arg)
        elseif cmd == "reset" then
            ns.Settings:ResetProfile()
        else
            ns.Print("Profile commands:")
            ns.Print("  /dhudlite profile list")
            ns.Print("  /dhudlite profile use <name>")
            ns.Print("  /dhudlite profile new <name>")
            ns.Print("  /dhudlite profile copy <source>")
            ns.Print("  /dhudlite profile delete <name>")
            ns.Print("  /dhudlite profile reset")
        end
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
    elseif msg == "debug" then
        ns.Print("=== DHUDLITE Debug ===")
        -- API existence
        ns.Print("issecretvalue: " .. tostring(issecretvalue ~= nil))
        ns.Print("canaccessvalue: " .. tostring(canaccessvalue ~= nil))
        ns.Print("UnitHealthPercent: " .. tostring(UnitHealthPercent ~= nil))
        ns.Print("UnitPowerPercent: " .. tostring(UnitPowerPercent ~= nil))
        ns.Print("CurveConstants: " .. tostring(CurveConstants ~= nil))
        if CurveConstants then
            ns.Print("  .ZeroToOne: " .. tostring(CurveConstants.ZeroToOne ~= nil) .. " type=" .. type(CurveConstants.ZeroToOne))
            ns.Print("  .ScaleTo100: " .. tostring(CurveConstants.ScaleTo100 ~= nil) .. " type=" .. type(CurveConstants.ScaleTo100))
            ns.Print("  .Reverse: " .. tostring(CurveConstants.Reverse ~= nil) .. " type=" .. type(CurveConstants.Reverse))
        end
        -- Health values
        local hp = UnitHealth("player")
        local hpMax = UnitHealthMax("player")
        ns.Print("UnitHealth: " .. tostring(hp) .. " secret=" .. tostring(issecretvalue and issecretvalue(hp) or "N/A"))
        ns.Print("UnitHealthMax: " .. tostring(hpMax) .. " secret=" .. tostring(issecretvalue and issecretvalue(hpMax) or "N/A"))
        if UnitHealthPercent and CurveConstants and CurveConstants.ZeroToOne then
            local pct01 = UnitHealthPercent("player", true, CurveConstants.ZeroToOne)
            ns.Print("UnitHealthPercent(ZeroToOne): " .. tostring(pct01) .. " secret=" .. tostring(issecretvalue and issecretvalue(pct01) or "N/A") .. " accessible=" .. tostring(not canaccessvalue or canaccessvalue(pct01)))
        elseif UnitHealthPercent then
            local raw = UnitHealthPercent("player")
            ns.Print("UnitHealthPercent(plain): " .. tostring(raw) .. " secret=" .. tostring(issecretvalue and issecretvalue(raw) or "N/A"))
        end
        -- Power values
        local pwType = UnitPowerType("player")
        local pw = UnitPower("player", pwType)
        local pwMax = UnitPowerMax("player", pwType)
        ns.Print("PowerType: " .. tostring(pwType))
        ns.Print("UnitPower: " .. tostring(pw) .. " secret=" .. tostring(issecretvalue and issecretvalue(pw) or "N/A"))
        ns.Print("UnitPowerMax: " .. tostring(pwMax) .. " secret=" .. tostring(issecretvalue and issecretvalue(pwMax) or "N/A"))
        if UnitPowerPercent and CurveConstants and CurveConstants.ZeroToOne then
            local ppct = UnitPowerPercent("player", pwType, true, CurveConstants.ZeroToOne)
            ns.Print("UnitPowerPercent(ZeroToOne): " .. tostring(ppct) .. " secret=" .. tostring(issecretvalue and issecretvalue(ppct) or "N/A") .. " accessible=" .. tostring(not canaccessvalue or canaccessvalue(ppct)))
        end
        -- Slot settings
        ns.Print("--- Slot Settings ---")
        local slotKeys = { "leftBig1","leftBig2","leftSmall1","leftSmall2","rightBig1","rightBig2","rightSmall1","rightSmall2" }
        for _, k in ipairs(slotKeys) do
            local val = ns.Settings:Get(k) or "(empty)"
            local def = ns.Settings:GetDefault(k) or "(empty)"
            local mark = (val ~= def) and " [CHANGED]" or ""
            ns.Print(string.format("  %s = %s%s", k, val, mark))
        end

        -- Tracker state
        local hm = ns.HUDManager
        if hm and hm.barSlots then
            for name, slot in pairs(hm.barSlots) do
                local t = slot.tracker
                if t then
                    local ca = not canaccessvalue or (canaccessvalue(t.amount) and canaccessvalue(t.amountMax))
                    ns.Print(string.format("Slot[%s]: unit=%s type=%s canAccess=%s amount=%s max=%s",
                        name, slot.unitId or "?", slot.barType or "?", tostring(ca),
                        tostring(t.amount), tostring(t.amountMax)))
                end
            end
        end
        -- Renderer state (via slot.renderer)
        if hm and hm.barSlots then
            for name, slot in pairs(hm.barSlots) do
                local r = slot.renderer
                if r then
                    ns.Print(string.format("Renderer[%s]: animating=%s target[1]=%s current[1]=%s sigTarget=%s",
                        name, tostring(r.isAnimating),
                        tostring(r.targetAnim and r.targetAnim[1]),
                        tostring(r.currentAnim and r.currentAnim[1]),
                        tostring(r.sigHeightTarget)))
                end
            end
        end
    else
        ns.Print("Commands:")
        ns.Print("  /dhudlite options - Open options panel")
        ns.Print("  /dhudlite move <on|off> - Toggle move mode")
        ns.Print("  /dhudlite visible <on|off> - Force HUD visible/hidden")
        ns.Print("  /dhudlite reset - Reset current profile to defaults")
        ns.Print("  /dhudlite profile - Profile management")
        ns.Print("  /dhudlite debug - Show diagnostic info")
    end
end
