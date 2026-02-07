local ADDON_NAME, ns = ...

local IconSlot = ns.CreateClass(ns.SlotBase, {})
ns.IconSlot = IconSlot

local Textures = ns.Textures
local Settings = ns.Settings
local TrackerHelper = ns.TrackerHelper

function IconSlot:New()
    local o = IconSlot.__index.New(self)
    o.pvpIcon = nil
    o.stateIcon = nil
    o.eliteIcon = nil
    o.raidIcon = nil
    o.unitInfoTracker = nil
    return o
end

function IconSlot:Init(pvpIcon, stateIcon, eliteIcon, raidIcon, unitInfoTracker)
    self.pvpIcon = pvpIcon
    self.stateIcon = stateIcon
    self.eliteIcon = eliteIcon
    self.raidIcon = raidIcon
    self.unitInfoTracker = unitInfoTracker
end

function IconSlot:Activate()
    ns.SlotBase.Activate(self)

    -- Listen to state events
    TrackerHelper.events:On("CombatChanged", self, self.UpdateStateIcon)
    TrackerHelper.events:On("RestingChanged", self, self.UpdateStateIcon)
    TrackerHelper.events:On("TargetChanged", self, self.UpdateTargetIcons)

    if self.unitInfoTracker then
        self.unitInfoTracker.events:On("DataChanged", self, self.UpdateTargetIcons)
    end

    self:UpdateStateIcon()
    self:UpdateTargetIcons()
end

function IconSlot:Deactivate()
    TrackerHelper.events:Off("CombatChanged", self, self.UpdateStateIcon)
    TrackerHelper.events:Off("RestingChanged", self, self.UpdateStateIcon)
    TrackerHelper.events:Off("TargetChanged", self, self.UpdateTargetIcons)

    if self.unitInfoTracker then
        self.unitInfoTracker.events:Off("DataChanged", self, self.UpdateTargetIcons)
    end

    if self.pvpIcon then self.pvpIcon:Hide() end
    if self.stateIcon then self.stateIcon:Hide() end
    if self.eliteIcon then self.eliteIcon:Hide() end
    if self.raidIcon then self.raidIcon:Hide() end
    ns.SlotBase.Deactivate(self)
end

function IconSlot:UpdateStateIcon()
    if not self.isActive or not self.stateIcon then return end
    if not Settings:Get("showCombatIcon") then
        self.stateIcon:Hide()
        return
    end

    if TrackerHelper.isInCombat then
        local info = Textures.list["BlizzardPlayerInCombat"]
        if info and self.stateIcon.texture then
            self.stateIcon.texture:SetTexture(info[1])
            self.stateIcon.texture:SetTexCoord(info[2], info[3], info[4], info[5])
        end
        self.stateIcon:Show()
    elseif TrackerHelper.isResting then
        local info = Textures.list["BlizzardPlayerResting"]
        if info and self.stateIcon.texture then
            self.stateIcon.texture:SetTexture(info[1])
            self.stateIcon.texture:SetTexCoord(info[2], info[3], info[4], info[5])
        end
        self.stateIcon:Show()
    else
        self.stateIcon:Hide()
    end
end

function IconSlot:UpdateTargetIcons()
    if not self.isActive then return end
    local t = self.unitInfoTracker

    -- PvP icon
    if self.pvpIcon then
        if Settings:Get("showPvPIcon") and UnitIsPVP("player") then
            local faction = UnitFactionGroup("player")
            local texName = (faction == "Horde") and "BlizzardPvPHorde"
                         or (faction == "Alliance") and "BlizzardPvPAlliance"
                         or "BlizzardPvPArena"
            local info = Textures.list[texName]
            if info and self.pvpIcon.texture then
                self.pvpIcon.texture:SetTexture(info[1])
                self.pvpIcon.texture:SetTexCoord(info[2], info[3], info[4], info[5])
            end
            self.pvpIcon:Show()
        else
            self.pvpIcon:Hide()
        end
    end

    -- Elite/Rare dragon
    if self.eliteIcon then
        if Settings:Get("showEliteDragon") and t and (t.isElite or t.isRare) then
            local texName = t.isRare and "TargetRareDragon" or "TargetEliteDragon"
            local info = Textures.list[texName]
            if info and self.eliteIcon.texture then
                self.eliteIcon.texture:SetTexture(info[1])
                self.eliteIcon.texture:SetTexCoord(1, 0, 0, 1) -- mirrored for right side
            end
            self.eliteIcon:Show()
        else
            self.eliteIcon:Hide()
        end
    end

    -- Raid target icon
    if self.raidIcon then
        if Settings:Get("showRaidIcon") and t and t.raidIcon > 0 then
            local texName = "BlizzardRaidIcon" .. t.raidIcon
            local info = Textures.list[texName]
            if info and self.raidIcon.texture then
                self.raidIcon.texture:SetTexture(info[1])
                self.raidIcon.texture:SetTexCoord(info[2], info[3], info[4], info[5])
            end
            self.raidIcon:Show()
        else
            self.raidIcon:Hide()
        end
    end
end
