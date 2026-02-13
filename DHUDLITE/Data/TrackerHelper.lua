local ADDON_NAME, ns = ...

local TrackerHelper = {}
ns.TrackerHelper = TrackerHelper

local eventsFrame = ns.CreateEventFrame()
local events = ns.EventBus:New()
TrackerHelper.events = events

-- State
TrackerHelper.timerMs = 0
TrackerHelper.tickId = 0
TrackerHelper.playerClass = ""
TrackerHelper.playerSpec = 0
TrackerHelper.isInVehicle = false
TrackerHelper.playerCasterUnitId = "player"
TrackerHelper.targetUnitId = "target"
TrackerHelper.targetOfTargetUnitId = "targettarget"
TrackerHelper.isTargetAvailable = false
TrackerHelper.isTargetOfTargetAvailable = false
TrackerHelper.isPetAvailable = false
TrackerHelper.isInCombat = false
TrackerHelper.isAttacking = false
TrackerHelper.isDead = false
TrackerHelper.isResting = false

-- Timer accumulators
local timeSinceFast = 0
local timeSinceNormal = 0
local timeSinceSlow = 0

function TrackerHelper:Init()
    local _, classToken = UnitClass("player")
    self.playerClass = classToken or ""

    eventsFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    eventsFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
    eventsFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventsFrame:RegisterEvent("UNIT_TARGET")
    eventsFrame:RegisterEvent("UNIT_PET")
    eventsFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventsFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
    eventsFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")
    eventsFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventsFrame:RegisterEvent("PLAYER_ALIVE")
    eventsFrame:RegisterEvent("PLAYER_DEAD")
    eventsFrame:RegisterEvent("PLAYER_UNGHOST")
    eventsFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
    eventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    function eventsFrame:UNIT_ENTERED_VEHICLE(unitId)
        if unitId ~= "player" then return end
        TrackerHelper:SetInVehicle(UnitHasVehicleUI and UnitHasVehicleUI("player") or false)
    end
    function eventsFrame:UNIT_EXITED_VEHICLE(unitId)
        if unitId ~= "player" then return end
        TrackerHelper:SetInVehicle(false)
    end
    function eventsFrame:PLAYER_TARGET_CHANGED()
        TrackerHelper:ProcessTargetChange()
    end
    function eventsFrame:UNIT_TARGET(unitId)
        if unitId ~= TrackerHelper.targetUnitId then return end
        TrackerHelper:SetTargetOfTargetAvailable(UnitExists(TrackerHelper.targetOfTargetUnitId))
    end
    function eventsFrame:UNIT_PET(unitId)
        if unitId ~= "player" then return end
        TrackerHelper:SetPetAvailable(HasPetUI and HasPetUI() or false)
    end
    function eventsFrame:PLAYER_REGEN_DISABLED()
        TrackerHelper:SetInCombat(true)
    end
    function eventsFrame:PLAYER_REGEN_ENABLED()
        TrackerHelper:SetInCombat(false)
    end
    function eventsFrame:PLAYER_ENTER_COMBAT()
        TrackerHelper:SetAttacking(true)
    end
    function eventsFrame:PLAYER_LEAVE_COMBAT()
        TrackerHelper:SetAttacking(false)
    end
    function eventsFrame:PLAYER_SPECIALIZATION_CHANGED(unitId)
        if unitId ~= "player" then return end
        TrackerHelper.playerSpec = GetSpecialization() or 0
        events:Fire("SpecChanged")
    end
    function eventsFrame:PLAYER_ALIVE()
        TrackerHelper:SetDead(UnitIsDeadOrGhost("player"))
    end
    function eventsFrame:PLAYER_DEAD()
        TrackerHelper:SetDead(true)
    end
    function eventsFrame:PLAYER_UNGHOST()
        TrackerHelper:SetDead(false)
    end
    function eventsFrame:PLAYER_UPDATE_RESTING()
        TrackerHelper:SetResting(IsResting())
    end
    function eventsFrame:PLAYER_ENTERING_WORLD()
        TrackerHelper:UpdateAllState()
        events:Fire("EnteringWorld")
    end

    self:UpdateAllState()
    self.timerMs = GetTime()
    eventsFrame:SetScript("OnUpdate", function(_, elapsed)
        TrackerHelper:OnUpdate(elapsed)
    end)
end

function TrackerHelper:OnUpdate(elapsed)
    self.tickId = self.tickId + 1
    self.timerMs = GetTime()
    timeSinceFast = timeSinceFast + elapsed
    -- Frequent: every frame (~10ms)
    events:Fire("UpdateFrequent", elapsed)
    -- Semi-frequent: ~45ms
    if timeSinceFast >= 0.045 then
        timeSinceNormal = timeSinceNormal + timeSinceFast
        timeSinceFast = 0
        events:Fire("UpdateSemiFrequent")
        -- Normal: ~95ms
        if timeSinceNormal >= 0.095 then
            timeSinceSlow = timeSinceSlow + timeSinceNormal
            timeSinceNormal = 0
            events:Fire("Update")
            -- Slow: ~1000ms
            if timeSinceSlow >= 1.0 then
                timeSinceSlow = 0
                events:Fire("UpdateSlow")
            end
        end
    end
end

function TrackerHelper:UpdateAllState()
    self:SetInCombat(UnitAffectingCombat("player") and true or false)
    self:SetAttacking(false)
    self:SetResting(IsResting() and true or false)
    self:SetDead(UnitIsDeadOrGhost("player") and true or false)
    self:SetInVehicle(UnitHasVehicleUI and UnitHasVehicleUI("player") and true or false)
    self:ProcessTargetChange()
    self:SetPetAvailable(HasPetUI and HasPetUI() and true or false)
    self.playerSpec = GetSpecialization() or 0
end

function TrackerHelper:SetInVehicle(val)
    if self.isInVehicle == val then return end
    self.isInVehicle = val
    self.playerCasterUnitId = val and "vehicle" or "player"
    events:Fire("VehicleChanged")
end

function TrackerHelper:ProcessTargetChange()
    local available = UnitExists("target")
    self.targetUnitId = "target"
    self.targetOfTargetUnitId = "targettarget"
    self:SetTargetAvailable(available)
    self:SetTargetOfTargetAvailable(UnitExists(self.targetOfTargetUnitId))
end

function TrackerHelper:SetTargetAvailable(val)
    if self.isTargetAvailable == val then return end
    self.isTargetAvailable = val
    events:Fire("TargetChanged")
end

function TrackerHelper:SetTargetOfTargetAvailable(val)
    if self.isTargetOfTargetAvailable == val then return end
    self.isTargetOfTargetAvailable = val
    events:Fire("TargetOfTargetChanged")
end

function TrackerHelper:SetPetAvailable(val)
    if self.isPetAvailable == val then return end
    self.isPetAvailable = val
    events:Fire("PetChanged")
end

function TrackerHelper:SetInCombat(val)
    if self.isInCombat == val then return end
    self.isInCombat = val
    events:Fire("CombatChanged")
end

function TrackerHelper:SetAttacking(val)
    if self.isAttacking == val then return end
    self.isAttacking = val
    events:Fire("AttackChanged")
end

function TrackerHelper:SetDead(val)
    if self.isDead == val then return end
    self.isDead = val
    events:Fire("DeathChanged")
end

function TrackerHelper:SetResting(val)
    if self.isResting == val then return end
    self.isResting = val
    events:Fire("RestingChanged")
end
