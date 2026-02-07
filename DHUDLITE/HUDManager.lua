local ADDON_NAME, ns = ...

local HUDManager = {}
ns.HUDManager = HUDManager

local Settings = ns.Settings
local Layout = ns.Layout
local TrackerHelper = ns.TrackerHelper

-- Trackers
local trackers = {}
-- Slots
local barSlots = {}
local castBarSlots = {}
local resourceSlot
local unitInfoSlot
local iconSlot

-- Tracker assignment map: setting value -> { unitId, barType }
local TRACKER_MAP = {
    playerHealth = { unitId = "player", barType = "health" },
    playerPower  = { unitId = "player", barType = "power" },
    targetHealth = { unitId = "target", barType = "health" },
    targetPower  = { unitId = "target", barType = "power" },
    petHealth    = { unitId = "pet",    barType = "health" },
    petPower     = { unitId = "pet",    barType = "power" },
    totHealth    = { unitId = "targettarget", barType = "health" },
    totPower     = { unitId = "targettarget", barType = "power" },
}

local function GetOrCreateTracker(key)
    if trackers[key] then return trackers[key] end
    local info = TRACKER_MAP[key]
    if not info then return nil end

    local tracker
    if info.barType == "health" then
        tracker = ns.HealthTracker:New(info.unitId)
    else
        tracker = ns.PowerTracker:New(info.unitId)
    end
    trackers[key] = tracker
    return tracker
end

local function GetClippingForSlot(slotName)
    if slotName:find("Big1") then return "TexturePrefixBarB1"
    elseif slotName:find("Big2") then return "TexturePrefixBarB2"
    elseif slotName:find("Small1") then return "TexturePrefixBarS1"
    elseif slotName:find("Small2") then return "TexturePrefixBarS2"
    end
    return "TexturePrefixBarB1"
end

local function GetSide(slotName)
    return slotName:find("^left") and "left" or "right"
end

-- Create and wire up a bar slot
local function SetupBarSlot(slotName)
    local trackerKey = Settings:Get(slotName) or ""
    if trackerKey == "" then return nil end

    local info = TRACKER_MAP[trackerKey]
    if not info then return nil end

    local tracker = GetOrCreateTracker(trackerKey)
    if not tracker then return nil end

    local side = GetSide(slotName)
    local clippingId = GetClippingForSlot(slotName)
    local group = Layout:GetBarGroup(slotName)
    local textFrame = Layout:GetTextFrame(slotName)
    local parentFrame = Layout:GetBarParent(slotName)

    local renderer = ns.BarRenderer:New(group, clippingId, side)
    renderer:SetParentFrame(parentFrame)

    local slot = ns.BarSlot:New(slotName, info.barType)
    slot:Init(renderer, textFrame, info.unitId)
    slot.tracker = tracker

    return slot
end

local function SetupCastBarSlot(side)
    local settingKey = (side == "left") and "leftCastBar" or "rightCastBar"
    local unitId = Settings:Get(settingKey) or ((side == "left") and "player" or "target")
    if unitId == "" then return nil end

    local clippingId = "CastingBarB1"
    local castFrames = (side == "left") and Layout.leftCastFrames or Layout.rightCastFrames
    if not castFrames then return nil end

    local renderer = ns.CastBarRenderer:New(clippingId, side)
    local parentFrame = Layout:GetBarParent(side .. "Big1")
    renderer:SetFrames(
        castFrames[1], -- castFrame
        castFrames[2], -- flashFrame
        castFrames[3], -- iconFrame
        castFrames[4], -- spellNameFrame
        castFrames[5], -- castTimeFrame
        castFrames[6], -- delayFrame
        parentFrame
    )

    local tracker = ns.CastTracker:New(unitId)
    trackers["cast_" .. side] = tracker

    local slot = ns.CastBarSlot:New(side)
    slot:Init(renderer, unitId)
    slot.tracker = tracker

    return slot
end

local function SetupResourceSlot()
    if not Settings:Get("showResources") then
        return nil
    end

    local tracker = ns.ComboTracker:New()
    trackers["combo"] = tracker

    local slot = ns.ResourceSlot:New()
    slot:Init(Layout.comboFrames, Layout.runeFrames)
    slot.tracker = tracker

    return slot
end

local function SetupUnitInfoSlot()
    if not Settings:Get("showUnitInfo") then return nil end

    local tracker = ns.UnitInfoTracker:New("target")
    trackers["unitInfo"] = tracker

    local slot = ns.UnitInfoSlot:New()
    slot:Init(Layout.centerText1, Layout.centerText2, "target")
    slot.tracker = tracker

    return slot
end

local function SetupIconSlot()
    local tracker = trackers["unitInfo"]
    local slot = ns.IconSlot:New()
    slot:Init(Layout.pvpIcon, Layout.stateIcon, Layout.eliteIcon, Layout.raidIcon, tracker)
    return slot
end

-- Calculate background mask for a side
local function CalculateBgMask(side)
    local mask = 0
    if (Settings:Get(side .. "Big1") or "") ~= "" then mask = mask + 1 end
    if (Settings:Get(side .. "Big2") or "") ~= "" then mask = mask + 2 end
    if (Settings:Get(side .. "Small1") or "") ~= "" then mask = mask + 4 end
    if (Settings:Get(side .. "Small2") or "") ~= "" then mask = mask + 8 end
    return mask
end

function HUDManager:Init()
    -- Setup bar slots
    local slotNames = { "leftBig1", "leftBig2", "leftSmall1", "leftSmall2",
                        "rightBig1", "rightBig2", "rightSmall1", "rightSmall2" }

    for _, slotName in ipairs(slotNames) do
        local slot = SetupBarSlot(slotName)
        if slot then
            barSlots[slotName] = slot
        end
    end

    -- Setup cast bar slots
    castBarSlots["left"] = SetupCastBarSlot("left")
    castBarSlots["right"] = SetupCastBarSlot("right")

    -- Setup resource slot
    resourceSlot = SetupResourceSlot()

    -- Setup unit info slot
    unitInfoSlot = SetupUnitInfoSlot()

    -- Setup icon slot
    iconSlot = SetupIconSlot()

    -- Apply backgrounds based on settings
    Layout:RefreshBackgrounds()

    -- Listen for target changes to start/stop target trackers
    TrackerHelper.events:On("TargetChanged", self, self.OnTargetChanged)
    TrackerHelper.events:On("TargetOfTargetChanged", self, self.OnTargetOfTargetChanged)
    TrackerHelper.events:On("Update", self, self.OnRangeUpdate)

    -- Listen for cast update rate changes and resubscribe
    Settings:OnChange("castUpdateRate", self, function()
        for _, slot in pairs(castBarSlots) do
            if slot and slot.Resubscribe then slot:Resubscribe() end
        end
    end)

    -- Listen for slot assignment changes and rebuild affected slots
    local function watchSlot(key)
        Settings:OnChange(key, self, function()
            self:RebuildSlot(key)
            Layout:RefreshBackgrounds()
        end)
    end
    local slotKeys = { "leftBig1","leftBig2","leftSmall1","leftSmall2","rightBig1","rightBig2","rightSmall1","rightSmall2" }
    for _, k in ipairs(slotKeys) do watchSlot(k) end
    Settings:OnChange("leftCastBar", self, function() self:RebuildCastSlot("left") end)
    Settings:OnChange("rightCastBar", self, function() self:RebuildCastSlot("right") end)

    -- Activate all slots
    self:ActivateAll()
end

function HUDManager:ActivateAll()
    for _, slot in pairs(barSlots) do
        slot:Activate()
    end
    for _, slot in pairs(castBarSlots) do
        slot:Activate()
    end
    if resourceSlot then
        resourceSlot:Activate()
    end
    if unitInfoSlot then
        unitInfoSlot:Activate()
    end
    if iconSlot then
        iconSlot:Activate()
    end
end

function HUDManager:DeactivateAll()
    for _, slot in pairs(barSlots) do
        slot:Deactivate()
    end
    for _, slot in pairs(castBarSlots) do
        slot:Deactivate()
    end
    if resourceSlot then
        resourceSlot:Deactivate()
    end
    if unitInfoSlot then
        unitInfoSlot:Deactivate()
    end
    if iconSlot then
        iconSlot:Deactivate()
    end
end

function HUDManager:OnTargetChanged()
    -- Refresh target-related trackers
    for key, tracker in pairs(trackers) do
        if tracker.unitId == "target" then
            if TrackerHelper.isTargetAvailable then
                if tracker.StartTracking and not tracker.isTracking then
                    tracker:StartTracking()
                end
                if tracker.UpdateAllData then
                    tracker:UpdateAllData()
                end
            end
        end
    end
end

function HUDManager:OnTargetOfTargetChanged()
    for key, tracker in pairs(trackers) do
        if tracker.unitId == "targettarget" then
            if TrackerHelper.isTargetOfTargetAvailable then
                if tracker.StartTracking and not tracker.isTracking then
                    tracker:StartTracking()
                end
                if tracker.UpdateAllData then
                    tracker:UpdateAllData()
                end
            else
                if tracker.isTracking and tracker.StopTracking then
                    tracker:StopTracking()
                end
            end
        end
    end
end

local function IsTargetInRange()
    if not UnitExists("target") then return true end
    -- Use interact distance 28yd for generic range check
    local ok = CheckInteractDistance("target", 4)
    if ok == 1 or ok == true then return true end
    return false
end

function HUDManager:OnRangeUpdate()
    if not ns.Settings:Get("rangeFade") then return end
    local inRange = IsTargetInRange()
    local a = inRange and 1 or (ns.Settings:Get("rangeFadeAlpha") or 0.35)
    Layout:SetSideAlpha("right", a)
end

-- Rebuild a specific bar slot when its setting changes
function HUDManager:RebuildSlot(slotName)
    -- Deactivate and clear old slot
    local old = barSlots[slotName]
    if old then
        old:Deactivate()
        barSlots[slotName] = nil
    end
    -- Create new slot with current setting
    local slot = SetupBarSlot(slotName)
    if slot then
        barSlots[slotName] = slot
        slot:Activate()
    else
        -- Ensure group's textures are hidden if no slot assigned
        local group = Layout:GetBarGroup(slotName)
        if group and group.SetFramesShown then group:SetFramesShown(0) end
        local textFrame = Layout:GetTextFrame(slotName)
        if textFrame and textFrame.textField and textFrame.textField.DSetText then textFrame.textField:DSetText("") end
    end
end

-- Rebuild the cast bar slot for a side
function HUDManager:RebuildCastSlot(side)
    local old = castBarSlots[side]
    if old then old:Deactivate() end
    castBarSlots[side] = SetupCastBarSlot(side)
    if castBarSlots[side] then castBarSlots[side]:Activate() end
end
