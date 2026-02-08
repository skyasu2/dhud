local ADDON_NAME, ns = ...

local PowerTracker = ns.CreateClass(nil, {})
ns.PowerTracker = PowerTracker

function PowerTracker:New(unitId, powerType)
    local o = PowerTracker.__index.New(self)
    o.unitId = unitId
    o.baseUnitId = unitId
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

    -- Also update on timer for secret values safety
    ns.TrackerHelper.events:On("Update", self, self.UpdatePower)

    -- React to vehicle/player caster unit changes
    ns.TrackerHelper.events:On("VehicleChanged", self, self.OnVehicleChanged)
end

function PowerTracker:StopTracking()
    if not self.isTracking then return end
    self.isTracking = false
    local ef = self.eventsFrame
    ef:UnregisterEvent("UNIT_POWER_UPDATE")
    ef:UnregisterEvent("UNIT_MAXPOWER")
    ef:UnregisterEvent("UNIT_DISPLAYPOWER")
    ns.TrackerHelper.events:Off("Update", self, self.UpdatePower)
    ns.TrackerHelper.events:Off("VehicleChanged", self, self.OnVehicleChanged)
end

function PowerTracker:UpdatePowerType()
    local id, token
    if self.forcedPowerType ~= nil then
        id = self.forcedPowerType
        -- Try to get current token anyway for coloring/text
        local _, t = UnitPowerType(self.unitId)
        token = t
    else
        id, token = UnitPowerType(self.unitId)
    end
    if not id then id = 0 end
    self.resourceType = id
    self.resourceTypeString = token or ""
    self.events:Fire("ResourceTypeChanged")
end

function PowerTracker:OnVehicleChanged()
    if self.baseUnitId == "player" then
        local caster = ns.TrackerHelper.playerCasterUnitId or "player"
        self.unitId = caster
        self:UpdatePowerType()
        self:UpdateAllData()
    end
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
