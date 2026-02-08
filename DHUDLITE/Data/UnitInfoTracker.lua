local ADDON_NAME, ns = ...

local UnitInfoTracker = ns.CreateClass(nil, {})
ns.UnitInfoTracker = UnitInfoTracker

-- Reaction IDs
UnitInfoTracker.REACTION_HOSTILE = 1
UnitInfoTracker.REACTION_NEUTRAL = 2
UnitInfoTracker.REACTION_FRIENDLY = 3
UnitInfoTracker.REACTION_FRIENDLY_PLAYER = 4
UnitInfoTracker.REACTION_FRIENDLY_PLAYER_PVP = 5
UnitInfoTracker.REACTION_NOT_TAPPED = 6

function UnitInfoTracker:New(unitId)
    local o = setmetatable({}, self)
    o.unitId = unitId
    o.name = ""
    o.level = 0
    o.classToken = ""
    o.classDisplayName = ""
    o.creatureType = ""
    o.reaction = UnitInfoTracker.REACTION_NEUTRAL
    o.isPvP = false
    o.isElite = false
    o.isRare = false
    o.isBoss = false
    o.raidIcon = 0
    o.isTracking = false
    o.events = ns.EventBus:New()
    o.eventsFrame = ns.CreateEventFrame()
    return o
end

function UnitInfoTracker:StartTracking()
    if self.isTracking then return end
    self.isTracking = true

    local tracker = self
    local ef = self.eventsFrame

    function ef:RAID_TARGET_UPDATE()
        tracker:UpdateAllData()
    end
    function ef:UNIT_NAME_UPDATE(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:UpdateAllData()
    end
    function ef:UNIT_LEVEL(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:UpdateAllData()
    end
    function ef:UNIT_CLASSIFICATION_CHANGED(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:UpdateAllData()
    end
    function ef:UNIT_FACTION(unitId)
        if unitId ~= tracker.unitId then return end
        tracker:UpdateAllData()
    end

    ef:RegisterEvent("RAID_TARGET_UPDATE")
    ef:RegisterEvent("UNIT_NAME_UPDATE")
    ef:RegisterEvent("UNIT_LEVEL")
    ef:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
    ef:RegisterEvent("UNIT_FACTION")

    self:UpdateAllData()
end

function UnitInfoTracker:StopTracking()
    if not self.isTracking then return end
    self.isTracking = false
    self.eventsFrame:UnregisterAllEvents()
end

function UnitInfoTracker:UpdateAllData()
    if not UnitExists(self.unitId) then
        self.name = ""
        self.level = 0
        self.classToken = ""
        self.classDisplayName = ""
        self.creatureType = ""
        self.reaction = UnitInfoTracker.REACTION_NEUTRAL
        self.isPvP = false
        self.isElite = false
        self.isRare = false
        self.isBoss = false
        self.raidIcon = 0
        self.events:Fire("DataChanged")
        return
    end

    self.name = UnitName(self.unitId) or ""
    self.level = UnitLevel(self.unitId) or 0
    local _, classToken = UnitClass(self.unitId)
    self.classToken = classToken or ""
    self.classDisplayName = UnitClass(self.unitId) or ""
    self.creatureType = UnitCreatureType(self.unitId) or ""
    self:UpdateReaction()
    self.isPvP = UnitIsPVP(self.unitId) or false

    -- Classification
    local classification = UnitClassification(self.unitId) or ""
    self.isElite = (classification == "elite" or classification == "worldboss" or classification == "rareelite")
    self.isRare = (classification == "rare" or classification == "rareelite")
    self.isBoss = (classification == "worldboss")

    -- Raid icon
    local idx = GetRaidTargetIndex(self.unitId)
    self.raidIcon = idx or 0

    self.events:Fire("DataChanged")
end

function UnitInfoTracker:UpdateReaction()
    if not UnitExists(self.unitId) then
        self.reaction = UnitInfoTracker.REACTION_NEUTRAL
        return
    end
    if UnitIsTapDenied(self.unitId) then
        self.reaction = UnitInfoTracker.REACTION_NOT_TAPPED
        return
    end
    if UnitIsPlayer(self.unitId) then
        if UnitIsFriend("player", self.unitId) then
            if UnitIsPVP(self.unitId) then
                self.reaction = UnitInfoTracker.REACTION_FRIENDLY_PLAYER_PVP
            else
                self.reaction = UnitInfoTracker.REACTION_FRIENDLY_PLAYER
            end
        else
            self.reaction = UnitInfoTracker.REACTION_HOSTILE
        end
        return
    end
    local unitReaction = UnitReaction("player", self.unitId) or 4
    if unitReaction <= 2 then
        self.reaction = UnitInfoTracker.REACTION_HOSTILE
    elseif unitReaction <= 4 then
        self.reaction = UnitInfoTracker.REACTION_NEUTRAL
    else
        self.reaction = UnitInfoTracker.REACTION_FRIENDLY
    end
end

local REACTION_COLOR_KEYS = {
    [1] = "colorReactionHostile",
    [2] = "colorReactionNeutral",
    [3] = "colorReactionFriendly",
    [4] = "colorReactionFriendlyPlayer",
    [5] = "colorReactionFriendlyPlayerPvP",
    [6] = "colorReactionNotTapped",
}

function UnitInfoTracker:GetReactionColor()
    local key = REACTION_COLOR_KEYS[self.reaction]
    if key then
        return ns.Settings:Get(key) or "ffffff"
    end
    return "ffffff"
end
