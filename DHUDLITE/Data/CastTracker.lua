local ADDON_NAME, ns = ...

local CastTracker = ns.CreateClass(nil, {})
ns.CastTracker = CastTracker

-- Cast states
CastTracker.STATE_NONE = 0
CastTracker.STATE_CASTING = 1
CastTracker.STATE_CHANNELING = 2
CastTracker.STATE_EMPOWERING = 3
CastTracker.STATE_INTERRUPTED = 4
CastTracker.STATE_SUCCEEDED = 5

function CastTracker:New(unitId)
    local o = CastTracker.__index.New(self)
    o.unitId = unitId
    o.state = CastTracker.STATE_NONE
    o.spellName = ""
    o.spellIcon = ""
    o.startTime = 0
    o.endTime = 0
    o.delay = 0
    o.notInterruptible = false
    o.empowerStages = 0
    o.empowerCurrentStage = 0
    o.empowerStageDurations = {}
    o.isTracking = false
    o.events = ns.EventBus:New()
    o.eventsFrame = ns.CreateEventFrame()
    return o
end

function CastTracker:StartTracking()
    if self.isTracking then return end
    self.isTracking = true
    local tracker = self
    local ef = self.eventsFrame

    function ef:UNIT_SPELLCAST_START(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:OnCastStart()
    end
    function ef:UNIT_SPELLCAST_STOP(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:OnCastStop()
    end
    function ef:UNIT_SPELLCAST_SUCCEEDED(unitId)
        if unitId ~= tracker.unitId then return end
        if tracker.state == CastTracker.STATE_CASTING then
            tracker:OnCastSucceeded()
        end
    end
    function ef:UNIT_SPELLCAST_FAILED(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:OnCastStop()
    end
    function ef:UNIT_SPELLCAST_INTERRUPTED(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:OnCastInterrupted()
    end
    function ef:UNIT_SPELLCAST_DELAYED(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:OnCastDelayed()
    end
    function ef:UNIT_SPELLCAST_CHANNEL_START(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:OnChannelStart()
    end
    function ef:UNIT_SPELLCAST_CHANNEL_STOP(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:OnCastStop()
    end
    function ef:UNIT_SPELLCAST_CHANNEL_UPDATE(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:OnChannelUpdate()
    end
    function ef:UNIT_SPELLCAST_EMPOWER_START(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:OnEmpowerStart()
    end
    function ef:UNIT_SPELLCAST_EMPOWER_STOP(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:OnCastStop()
    end
    function ef:UNIT_SPELLCAST_EMPOWER_UPDATE(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:OnEmpowerUpdate()
    end

    ef:RegisterEvent("UNIT_SPELLCAST_START")
    ef:RegisterEvent("UNIT_SPELLCAST_STOP")
    ef:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    ef:RegisterEvent("UNIT_SPELLCAST_FAILED")
    ef:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    ef:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    ef:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    ef:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    ef:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    ef:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")

    self:CheckCurrentCast()
end

function CastTracker:StopTracking()
    if not self.isTracking then return end
    self.isTracking = false
    local ef = self.eventsFrame
    ef:UnregisterEvent("UNIT_SPELLCAST_START")
    ef:UnregisterEvent("UNIT_SPELLCAST_STOP")
    ef:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    ef:UnregisterEvent("UNIT_SPELLCAST_FAILED")
    ef:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    ef:UnregisterEvent("UNIT_SPELLCAST_DELAYED")
    ef:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    ef:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    ef:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    ef:UnregisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    ef:UnregisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    ef:UnregisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
end

function CastTracker:CheckCurrentCast()
    local name, _, _, startMs, endMs, _, _, notInterruptible = UnitCastingInfo(self.unitId)
    if name then
        self.spellName = name
        self.spellIcon = select(3, UnitCastingInfo(self.unitId)) or ""
        self.startTime = startMs / 1000
        self.endTime = endMs / 1000
        self.notInterruptible = notInterruptible or false
        self.delay = 0
        self.state = CastTracker.STATE_CASTING
        self.events:Fire("CastChanged")
        return
    end
    name, _, _, startMs, endMs, _, notInterruptible = UnitChannelInfo(self.unitId)
    if name then
        self.spellName = name
        self.spellIcon = select(3, UnitChannelInfo(self.unitId)) or ""
        self.startTime = startMs / 1000
        self.endTime = endMs / 1000
        self.notInterruptible = notInterruptible or false
        self.delay = 0
        -- Check if empowering
        local numStages = 0
        if UnitChannelInfo(self.unitId) then
            -- Empower detection via extra args in 12.0
            numStages = select(8, UnitChannelInfo(self.unitId)) or 0
        end
        if numStages > 0 then
            self.state = CastTracker.STATE_EMPOWERING
            self.empowerStages = numStages
        else
            self.state = CastTracker.STATE_CHANNELING
        end
        self.events:Fire("CastChanged")
        return
    end
    if self.state ~= CastTracker.STATE_NONE then
        self.state = CastTracker.STATE_NONE
        self.events:Fire("CastChanged")
    end
end

function CastTracker:OnCastStart()
    local name, _, texture, startMs, endMs, _, _, notInterruptible = UnitCastingInfo(self.unitId)
    if not name then return end
    self.spellName = name
    self.spellIcon = texture or ""
    self.startTime = startMs / 1000
    self.endTime = endMs / 1000
    self.notInterruptible = notInterruptible or false
    self.delay = 0
    self.state = CastTracker.STATE_CASTING
    self.events:Fire("CastChanged")
end

function CastTracker:OnCastStop()
    if self.state == CastTracker.STATE_NONE then return end
    self.state = CastTracker.STATE_NONE
    self.events:Fire("CastChanged")
end

function CastTracker:OnCastSucceeded()
    self.state = CastTracker.STATE_SUCCEEDED
    self.events:Fire("CastChanged")
    -- Brief flash then clear
    C_Timer.After(0.3, function()
        if self.state == CastTracker.STATE_SUCCEEDED then
            self.state = CastTracker.STATE_NONE
            self.events:Fire("CastChanged")
        end
    end)
end

function CastTracker:OnCastInterrupted()
    self.state = CastTracker.STATE_INTERRUPTED
    self.events:Fire("CastChanged")
    C_Timer.After(0.5, function()
        if self.state == CastTracker.STATE_INTERRUPTED then
            self.state = CastTracker.STATE_NONE
            self.events:Fire("CastChanged")
        end
    end)
end

function CastTracker:OnCastDelayed()
    local name, _, _, startMs, endMs = UnitCastingInfo(self.unitId)
    if not name then return end
    local newStart = startMs / 1000
    self.delay = self.delay + (newStart - self.startTime)
    self.startTime = newStart
    self.endTime = endMs / 1000
    self.events:Fire("CastChanged")
end

function CastTracker:OnChannelStart()
    local name, _, texture, startMs, endMs, _, notInterruptible = UnitChannelInfo(self.unitId)
    if not name then return end
    self.spellName = name
    self.spellIcon = texture or ""
    self.startTime = startMs / 1000
    self.endTime = endMs / 1000
    self.notInterruptible = notInterruptible or false
    self.delay = 0
    self.state = CastTracker.STATE_CHANNELING
    self.events:Fire("CastChanged")
end

function CastTracker:OnChannelUpdate()
    local name, _, _, startMs, endMs = UnitChannelInfo(self.unitId)
    if not name then return end
    local newEnd = endMs / 1000
    self.delay = self.delay + (self.endTime - newEnd)
    self.startTime = startMs / 1000
    self.endTime = newEnd
    self.events:Fire("CastChanged")
end

function CastTracker:OnEmpowerStart()
    local name, _, texture, startMs, endMs, _, notInterruptible, numStages = UnitChannelInfo(self.unitId)
    if not name then return end
    self.spellName = name
    self.spellIcon = texture or ""
    self.startTime = startMs / 1000
    self.endTime = endMs / 1000
    self.notInterruptible = notInterruptible or false
    self.delay = 0
    self.empowerStages = numStages or 0
    self.empowerStageDurations = {}
    if GetUnitEmpowerStageDuration then
        for i = 1, self.empowerStages do
            self.empowerStageDurations[i] = (GetUnitEmpowerStageDuration(self.unitId, i - 1) or 0) / 1000
        end
    end
    self.state = CastTracker.STATE_EMPOWERING
    self.events:Fire("CastChanged")
end

function CastTracker:OnEmpowerUpdate()
    self:OnEmpowerStart()
end

function CastTracker:GetProgress()
    if self.state == CastTracker.STATE_NONE then return 0 end
    if self.state == CastTracker.STATE_INTERRUPTED then return 1 end
    if self.state == CastTracker.STATE_SUCCEEDED then return 1 end
    local now = GetTime()
    local duration = self.endTime - self.startTime
    if duration <= 0 then return 1 end
    local elapsed = now - self.startTime
    local pct = elapsed / duration
    if pct < 0 then pct = 0 end
    if pct > 1 then pct = 1 end
    -- Channel/empower fills in reverse
    if self.state == CastTracker.STATE_CHANNELING then
        pct = 1 - pct
    end
    return pct
end
