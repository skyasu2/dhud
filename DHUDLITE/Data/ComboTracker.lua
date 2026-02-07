local ADDON_NAME, ns = ...

local ComboTracker = ns.CreateClass(nil, {})
ns.ComboTracker = ComboTracker

-- Resource types
ComboTracker.TYPE_COMBO = "COMBO"
ComboTracker.TYPE_RUNES = "RUNES"
ComboTracker.TYPE_HOLY_POWER = "HOLY_POWER"
ComboTracker.TYPE_CHI = "CHI"
ComboTracker.TYPE_SOUL_SHARDS = "SOUL_SHARDS"
ComboTracker.TYPE_ARCANE_CHARGES = "ARCANE_CHARGES"
ComboTracker.TYPE_ESSENCE = "ESSENCE"
ComboTracker.TYPE_NONE = "NONE"

function ComboTracker:New()
    local o = ComboTracker.__index.New(self)
    o.resourceType = ComboTracker.TYPE_NONE
    o.count = 0
    o.countMax = 0
    o.runeStates = {} -- For DK: { ready, cooldownStart, cooldownDuration }
    o.isTracking = false
    o.events = ns.EventBus:New()
    o.eventsFrame = ns.CreateEventFrame()
    return o
end

-- Map classes to resource types
local CLASS_RESOURCES = {
    ROGUE       = { type = "COMBO",          power = Enum.PowerType.ComboPoints },
    DRUID       = { type = "COMBO",          power = Enum.PowerType.ComboPoints },
    PALADIN     = { type = "HOLY_POWER",     power = Enum.PowerType.HolyPower },
    MONK        = { type = "CHI",            power = Enum.PowerType.Chi },
    WARLOCK     = { type = "SOUL_SHARDS",    power = Enum.PowerType.SoulShards },
    MAGE        = { type = "ARCANE_CHARGES", power = Enum.PowerType.ArcaneCharges },
    EVOKER      = { type = "ESSENCE",        power = Enum.PowerType.Essence },
    DEATHKNIGHT = { type = "RUNES",          power = nil },
}

function ComboTracker:StartTracking()
    if self.isTracking then return end
    self.isTracking = true
    local tracker = self
    local ef = self.eventsFrame
    local playerClass = ns.TrackerHelper.playerClass

    local info = CLASS_RESOURCES[playerClass]
    if not info then
        self.resourceType = ComboTracker.TYPE_NONE
        return
    end

    self.resourceType = info.type

    if self.resourceType == ComboTracker.TYPE_RUNES then
        function ef:RUNE_POWER_UPDATE(runeIndex, usable)
            tracker:UpdateRunes()
        end
        ef:RegisterEvent("RUNE_POWER_UPDATE")
        self:UpdateRunes()
    else
        function ef:UNIT_POWER_UPDATE(unitId, powerToken)
            if unitId ~= "player" then return end
            tracker:UpdateClassResource()
        end
        function ef:UNIT_MAXPOWER(unitId, powerToken)
            if unitId ~= "player" then return end
            tracker:UpdateClassResource()
        end
        ef:RegisterEvent("UNIT_POWER_UPDATE")
        ef:RegisterEvent("UNIT_MAXPOWER")
        self:UpdateClassResource()
    end
end

function ComboTracker:StopTracking()
    if not self.isTracking then return end
    self.isTracking = false
    self.eventsFrame:UnregisterEvent("RUNE_POWER_UPDATE")
    self.eventsFrame:UnregisterEvent("UNIT_POWER_UPDATE")
    self.eventsFrame:UnregisterEvent("UNIT_MAXPOWER")
end

function ComboTracker:UpdateClassResource()
    local info = CLASS_RESOURCES[ns.TrackerHelper.playerClass]
    if not info or not info.power then return end
    self.count = UnitPower("player", info.power) or 0
    self.countMax = UnitPowerMax("player", info.power) or 0
    self.events:Fire("DataChanged")
end

function ComboTracker:UpdateRunes()
    if not GetRuneCooldown then return end
    local numRunes = 6
    local readyCount = 0
    for i = 1, numRunes do
        local start, duration, ready = GetRuneCooldown(i)
        self.runeStates[i] = {
            ready = ready,
            start = start or 0,
            duration = duration or 0,
        }
        if ready then
            readyCount = readyCount + 1
        end
    end
    self.count = readyCount
    self.countMax = numRunes
    self.events:Fire("DataChanged")
end
