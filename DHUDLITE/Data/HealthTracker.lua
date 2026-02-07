local ADDON_NAME, ns = ...

local HealthTracker = ns.CreateClass(nil, {})
ns.HealthTracker = HealthTracker

function HealthTracker:New(unitId)
    local o = HealthTracker.__index.New(self)
    o.unitId = unitId
    o.amount = 0
    o.amountMax = 1
    o.amountMaxUnmodified = 0
    o.amountExtra = 0       -- absorb shield
    o.amountExtraMax = 0
    o.amountHealIncoming = 0
    o.amountHealAbsorb = 0
    o.amountMaxHealthReduce = 0
    o.amountHealthModifier = 0
    o.noCreditForKill = false
    o.isTracking = false
    o.events = ns.EventBus:New()
    o.eventsFrame = ns.CreateEventFrame()
    return o
end

function HealthTracker:StartTracking()
    if self.isTracking then return end
    self.isTracking = true
    local tracker = self
    local ef = self.eventsFrame

    function ef:UNIT_HEALTH(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:UpdateHealth()
    end
    function ef:UNIT_MAXHEALTH(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:UpdateMaxHealth()
    end
    function ef:UNIT_HEAL_PREDICTION(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:UpdateIncomingHeal()
    end
    function ef:UNIT_ABSORB_AMOUNT_CHANGED(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:UpdateAbsorbs()
    end
    function ef:UNIT_HEAL_ABSORB_AMOUNT_CHANGED(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:UpdateHealAbsorb()
    end
    function ef:UNIT_MAX_HEALTH_MODIFIERS_CHANGED(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:UpdateMaxHpModifier()
    end

    ef:RegisterEvent("UNIT_HEALTH")
    ef:RegisterEvent("UNIT_MAXHEALTH")
    ef:RegisterEvent("UNIT_HEAL_PREDICTION")
    ef:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
    ef:RegisterEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED")
    ef:RegisterEvent("UNIT_MAX_HEALTH_MODIFIERS_CHANGED")

    -- Also update on timer for secret values safety
    ns.TrackerHelper.events:On("Update", self, self.UpdateHealth)

    self:UpdateAllData()
end

function HealthTracker:StopTracking()
    if not self.isTracking then return end
    self.isTracking = false
    local ef = self.eventsFrame
    ef:UnregisterEvent("UNIT_HEALTH")
    ef:UnregisterEvent("UNIT_MAXHEALTH")
    ef:UnregisterEvent("UNIT_HEAL_PREDICTION")
    ef:UnregisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
    ef:UnregisterEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED")
    ef:UnregisterEvent("UNIT_MAX_HEALTH_MODIFIERS_CHANGED")
    ns.TrackerHelper.events:Off("Update", self, self.UpdateHealth)
end

function HealthTracker:UpdateHealth()
    local val = UnitHealth(self.unitId) or 0
    if val ~= self.amount then
        self.amount = val
        self.events:Fire("DataChanged")
    end
end

function HealthTracker:UpdateMaxHealth()
    local val = UnitHealthMax(self.unitId) or 0
    self.amountMaxUnmodified = val
    if self.amountHealthModifier == 0 then
        self.amountMax = val
    else
        local amountMax = math.floor(val / (1 - self.amountHealthModifier) + 0.5)
        self.amountMaxHealthReduce = amountMax - val
        self.amountMax = amountMax
    end
    if self.amountMax <= 0 then self.amountMax = 1 end
    self.events:Fire("DataChanged")
end

function HealthTracker:UpdateAbsorbs()
    self.amountExtra = UnitGetTotalAbsorbs(self.unitId) or 0
    self.amountExtraMax = self.amountExtra
    self.events:Fire("DataChanged")
end

function HealthTracker:UpdateIncomingHeal()
    local val = UnitGetIncomingHeals(self.unitId) or 0
    if val ~= self.amountHealIncoming then
        self.amountHealIncoming = val
        self.events:Fire("DataChanged")
    end
end

function HealthTracker:UpdateHealAbsorb()
    local val = UnitGetTotalHealAbsorbs(self.unitId) or 0
    if val ~= self.amountHealAbsorb then
        self.amountHealAbsorb = val
        self.events:Fire("DataChanged")
    end
end

function HealthTracker:UpdateMaxHpModifier()
    local val = 0
    if GetUnitTotalModifiedMaxHealthPercent then
        val = GetUnitTotalModifiedMaxHealthPercent(self.unitId) or 0
    end
    if val >= 1 or val < 0 then return end
    if val ~= self.amountHealthModifier then
        self.amountHealthModifier = val
        local amountMax = math.floor(self.amountMaxUnmodified / (1 - val) + 0.5)
        self.amountMaxHealthReduce = amountMax - self.amountMaxUnmodified
        self.amountMax = amountMax
        if self.amountMax <= 0 then self.amountMax = 1 end
        self.events:Fire("DataChanged")
    end
end

function HealthTracker:UpdateNoCreditForKill()
    local val = UnitIsTapDenied(self.unitId) and true or false
    if val ~= self.noCreditForKill then
        self.noCreditForKill = val
        self.events:Fire("DataChanged")
    end
end

function HealthTracker:UpdateAllData()
    self.amountExtra = 0
    self.amountExtraMax = 0
    self:UpdateAbsorbs()
    self:UpdateIncomingHeal()
    self:UpdateHealAbsorb()
    self:UpdateMaxHealth()
    self:UpdateMaxHpModifier()
    self:UpdateNoCreditForKill()
    self:UpdateHealth()
end
