local ADDON_NAME, ns = ...

local PowerTracker = ns.CreateClass(nil, {})
ns.PowerTracker = PowerTracker

function PowerTracker:New(unitId, powerType)
    local o = PowerTracker.__index.New(self)
    o.unitId = unitId
    o.forcedPowerType = powerType -- nil = auto-detect display power
    o.amount = 0
    o.amountMax = 1
    o.amountMin = 0
    o.resourceType = 0
    o.resourceTypeString = "MANA"
    o.isTracking = false
    o.events = ns.EventBus:New()
    o.eventsFrame = ns.CreateEventFrame()
    return o
end

function PowerTracker:StartTracking()
    if self.isTracking then return end
    self.isTracking = true
    local tracker = self
    local ef = self.eventsFrame

    function ef:UNIT_POWER_UPDATE(unitId, powerToken)
        if unitId ~= tracker.unitId then return end
        tracker:UpdatePower()
    end
    function ef:UNIT_MAXPOWER(unitId, powerToken)
        if unitId ~= tracker.unitId then return end
        tracker:UpdateMaxPower()
    end
    function ef:UNIT_DISPLAYPOWER(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:UpdatePowerType()
    end

    ef:RegisterEvent("UNIT_POWER_UPDATE")
    ef:RegisterEvent("UNIT_MAXPOWER")
    ef:RegisterEvent("UNIT_DISPLAYPOWER")

    self:UpdatePowerType()
    self:UpdateAllData()
end

function PowerTracker:StopTracking()
    if not self.isTracking then return end
    self.isTracking = false
    local ef = self.eventsFrame
    ef:UnregisterEvent("UNIT_POWER_UPDATE")
    ef:UnregisterEvent("UNIT_MAXPOWER")
    ef:UnregisterEvent("UNIT_DISPLAYPOWER")
end

function PowerTracker:UpdatePowerType()
    if self.forcedPowerType then
        self.resourceType = self.forcedPowerType
    else
        self.resourceType = UnitPowerType(self.unitId) or 0
    end
    -- Map power type to string
    local POWER_STRINGS = {
        [0] = "MANA", [1] = "RAGE", [2] = "FOCUS", [3] = "ENERGY",
        [6] = "RUNIC_POWER", [8] = "LUNAR_POWER", [11] = "MAELSTROM",
        [13] = "INSANITY", [17] = "FURY", [18] = "PAIN",
    }
    self.resourceTypeString = POWER_STRINGS[self.resourceType] or "MANA"
    self.events:Fire("ResourceTypeChanged")
end

function PowerTracker:UpdatePower()
    local val = UnitPower(self.unitId, self.resourceType) or 0
    if val ~= self.amount then
        self.amount = val
        self.events:Fire("DataChanged")
    end
end

function PowerTracker:UpdateMaxPower()
    local val = UnitPowerMax(self.unitId, self.resourceType) or 0
    if val <= 0 then val = 1 end
    self.amountMax = val
    -- Some powers have min values (e.g., balance druid)
    self.amountMin = 0
    self.events:Fire("DataChanged")
end

function PowerTracker:UpdateAllData()
    self:UpdateMaxPower()
    self:UpdatePower()
end
