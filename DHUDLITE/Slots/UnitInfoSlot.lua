local ADDON_NAME, ns = ...

local UnitInfoSlot = ns.CreateClass(ns.SlotBase, {})
ns.UnitInfoSlot = UnitInfoSlot

local Colorize = ns.Colorize
local TextFormat = ns.TextFormat

function UnitInfoSlot:New()
    local o = UnitInfoSlot.__index.New(self)
    o.textField1 = nil -- name + level line
    o.textField2 = nil -- class / creature type line
    o.unitId = "target"
    return o
end

function UnitInfoSlot:Init(textFrame1, textFrame2, unitId)
    if textFrame1 then
        self.textField1 = textFrame1.textField
    end
    if textFrame2 then
        self.textField2 = textFrame2.textField
    end
    if unitId then
        self.unitId = unitId
    end
end

function UnitInfoSlot:Activate()
    ns.SlotBase.Activate(self)
    if self.tracker then
        self:BindTracker(self.tracker, {
            DataChanged = self.OnDataChanged,
        })
        self.tracker:StartTracking()
    end
    -- Also listen for target changes
    ns.TrackerHelper.events:On("TargetChanged", self, self.OnTargetChanged)
    self:OnTargetChanged()
end

function UnitInfoSlot:Deactivate()
    ns.TrackerHelper.events:Off("TargetChanged", self, self.OnTargetChanged)
    if self.tracker then
        self.tracker:StopTracking()
    end
    if self.textField1 then
        self.textField1:DSetText("")
    end
    if self.textField2 then
        self.textField2:DSetText("")
    end
    ns.SlotBase.Deactivate(self)
end

function UnitInfoSlot:OnTargetChanged()
    if not self.isActive or not self.tracker then return end
    self.tracker:UpdateAllData()
end

function UnitInfoSlot:OnDataChanged()
    if not self.isActive or not self.tracker then return end
    local t = self.tracker

    if t.name == "" then
        if self.textField1 then self.textField1:DSetText("") end
        if self.textField2 then self.textField2:DSetText("") end
        return
    end

    -- Line 1: [Level] Name (colored by reaction)
    if self.textField1 then
        local nameStr = t.name
        local reactionHex = t:GetReactionColor()
        local levelStr = ""
        if t.level > 0 then
            local lr, lg, lb = Colorize:GetDifficultyColor(t.level)
            levelStr = Colorize:ColorizeString(tostring(t.level), lr, lg, lb) .. " "
        elseif t.level == -1 then
            levelStr = Colorize:ColorizeString("??", 1, 0, 0) .. " "
        end
        local coloredName = string.format("|cff%s%s|r", reactionHex, nameStr)
        self.textField1:DSetText(levelStr .. coloredName)
    end

    -- Line 2: Class or creature type
    if self.textField2 then
        local infoStr = ""
        if t.classToken ~= "" and UnitIsPlayer(t.unitId) then
            local cr, cg, cb = Colorize:GetClassColor(t.classToken)
            infoStr = Colorize:ColorizeString(t.classDisplayName, cr, cg, cb)
        elseif t.creatureType ~= "" then
            infoStr = t.creatureType
        end
        self.textField2:DSetText(infoStr)
    end
end
