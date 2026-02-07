local ADDON_NAME, ns = ...

local Settings = {}
ns.Settings = Settings

local defaults = {
    -- Bar texture style (1-5)
    barsTexture = 2,
    -- Show background
    showBackground = true,
    -- Bar distance from center (half-distance, pixels)
    barsDistanceDiv2 = 60,
    -- Alpha settings
    alphaInCombat = 1.0,
    alphaHasTarget = 0.7,
    alphaResting = 0.3,
    alphaIdle = 0.0,
    -- Alpha fade speed
    alphaFadeSpeed = 3.0,
    -- Show bars when dead
    hideWhenDead = true,
    -- Animation
    animateBars = true,
    -- Short numbers (K/M)
    shortNumbers = true,
    -- Scale
    scaleMain = 1.0,
    scaleResources = 1.0,
    -- Update cadence for cast bar ("semi" ~45ms, "normal" ~95ms)
    castUpdateRate = "semi",
    -- Font sizes
    fontSizeBars = 10,
    fontSizeInfo = 10,
    fontSizeCast = 10,
    -- Text outlines (0=none, 1=OUTLINE, 2=THICKOUTLINE)
    fontOutline = 0,
    -- Health bar layers
    showHealthShield = true,
    showHealthShieldOverMax = true,
    showHealthHealAbsorb = true,
    showHealthReduce = true,
    showHealthHealIncoming = true,
    -- Colors (hex strings)
    colorPlayerHealth = { "00ff00", "ffff00", "ff0000" },
    colorTargetHealth = { "00ff00", "ffff00", "ff0000" },
    colorPetHealth = { "00ff00", "ffff00", "ff0000" },
    colorHealthShield = { "ffff88" },
    colorHealthAbsorb = { "ff4444" },
    colorHealthReduce = { "884444" },
    colorHealthHeal = { "44ff44" },
    colorHealthNotTapped = { "888888" },
    colorPlayerMana = { "4444ff" },
    colorPlayerRage = { "ff0000" },
    colorPlayerEnergy = { "ffff00" },
    colorPlayerFocus = { "ff8800" },
    colorPlayerRunicPower = { "00ddff" },
    colorPlayerLunarPower = { "4488ff" },
    colorPlayerMaelstrom = { "0088ff" },
    colorPlayerInsanity = { "8800ff" },
    colorPlayerFury = { "c842fc" },
    colorPlayerPain = { "ff9900" },
    colorTargetMana = { "4444ff" },
    colorTargetRage = { "ff0000" },
    colorTargetEnergy = { "ffff00" },
    colorCastCast = { "ffff00" },
    colorCastChannel = { "00ff00" },
    colorCastLockedCast = { "888800" },
    colorCastLockedChannel = { "008800" },
    colorCastInterrupted = { "ff0000" },
    -- Reaction colors
    colorReactionHostile = "ff0000",
    colorReactionNeutral = "ffff00",
    colorReactionFriendly = "55ff55",
    colorReactionFriendlyPlayer = "8888ff",
    colorReactionFriendlyPlayerPvP = "008800",
    colorReactionNotTapped = "cccccc",
    -- Slot assignments: which data tracker for which slot
    leftBig1 = "playerHealth",
    leftBig2 = "playerPower",
    leftSmall1 = "",
    leftSmall2 = "",
    rightBig1 = "targetHealth",
    rightBig2 = "targetPower",
    rightSmall1 = "totHealth",
    rightSmall2 = "totPower",
    -- Cast bars
    leftCastBar = "player",
    rightCastBar = "target",
    -- Resources
    showComboPoints = true,
    showDKRunes = true,
    showClassResources = true,
    -- Icons
    showPvPIcon = true,
    showCombatIcon = true,
    showEliteDragon = true,
    showRaidIcon = true,
    -- Unit info
    showUnitInfo = true,
}

local db
local changeCallbacks = {}

function Settings:Init()
    if not DHUDLITE_DB then
        DHUDLITE_DB = {}
    end
    db = DHUDLITE_DB
    -- Apply defaults for missing keys
    for k, v in pairs(defaults) do
        if db[k] == nil then
            if type(v) == "table" then
                db[k] = {}
                for i, sv in ipairs(v) do
                    db[k][i] = sv
                end
            else
                db[k] = v
            end
        end
    end
end

function Settings:Get(key)
    if db then
        local val = db[key]
        if val ~= nil then return val end
    end
    return defaults[key]
end

function Settings:Set(key, value)
    if not db then return end
    db[key] = value
    -- Fire change callbacks
    local cbs = changeCallbacks[key]
    if cbs then
        for i = 1, #cbs do
            local entry = cbs[i]
            entry.fn(entry.obj, key, value)
        end
    end
    ns.events:Fire("SettingChanged", key, value)
end

function Settings:OnChange(key, obj, func)
    local cbs = changeCallbacks[key]
    if not cbs then
        cbs = {}
        changeCallbacks[key] = cbs
    end
    cbs[#cbs + 1] = { obj = obj, fn = func }
end

function Settings:GetDefault(key)
    return defaults[key]
end

function Settings:Reset(key)
    self:Set(key, defaults[key])
end
