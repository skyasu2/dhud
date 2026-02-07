local ADDON_NAME, ns = ...

local CastBarSlot = ns.CreateClass(ns.SlotBase, {})
ns.CastBarSlot = CastBarSlot

local CT = ns.CastTracker
local Colorize = ns.Colorize

function CastBarSlot:New(side)
    local o = CastBarSlot.__index.New(self)
    o.side = side
    o.renderer = nil
    o.unitId = (side == "left") and "player" or "target"
    o.updateEvent = nil
    return o
end

function CastBarSlot:Init(renderer, unitId)
    self.renderer = renderer
    if unitId then
        self.unitId = unitId
    end
end

function CastBarSlot:Activate()
    ns.SlotBase.Activate(self)
    if self.tracker then
        self:BindTracker(self.tracker, {
            CastChanged = self.OnCastChanged,
        })
        self.tracker:StartTracking()
        self:OnCastChanged()
    end
end

function CastBarSlot:Deactivate()
    self:Unsubscribe()
    if self.tracker then
        self.tracker:StopTracking()
    end
    if self.renderer then
        self.renderer:HideCast()
    end
    ns.SlotBase.Deactivate(self)
end

function CastBarSlot:OnCastChanged()
    if not self.isActive or not self.tracker or not self.renderer then return end
    local t = self.tracker
    local state = t.state

    if state == CT.STATE_NONE then
        self.renderer:HideCast()
        return
    end

    if state == CT.STATE_INTERRUPTED then
        local r, g, b = Colorize:GetCastColor(state, self.unitId)
        self.renderer:UpdateFill(1, r, g, b)
        self.renderer:UpdateTexts(t)
        return
    end

    if state == CT.STATE_SUCCEEDED then
        local r, g, b = Colorize:GetCastColor(CT.STATE_CASTING, self.unitId)
        self.renderer:UpdateFill(1, r, g, b)
        self.renderer:StartFlash()
        return
    end

    -- Active cast/channel/empower
    self.renderer:ShowCast(t)
    self:UpdateCastFill()

    -- Subscribe to updates for progress, per setting
    self:Subscribe()
end

function CastBarSlot:UpdateCastFill()
    if not self.isActive or not self.tracker then
        self:Unsubscribe()
        return
    end

    local t = self.tracker
    local state = t.state

    if state == CT.STATE_NONE or state == CT.STATE_INTERRUPTED or state == CT.STATE_SUCCEEDED then
        self:Unsubscribe()
        return
    end

    local pct = t:GetProgress()
    local r, g, b = Colorize:GetCastColor(state, self.unitId)

    -- Locked color for non-interruptible casts
    if t.notInterruptible then
        if state == CT.STATE_CASTING then
            local hexTable = ns.Settings:Get("colorCastLockedCast")
            if hexTable and #hexTable > 0 then
                r, g, b = Colorize:HexToRGB(hexTable[1])
            end
        elseif state == CT.STATE_CHANNELING then
            local hexTable = ns.Settings:Get("colorCastLockedChannel")
            if hexTable and #hexTable > 0 then
                r, g, b = Colorize:HexToRGB(hexTable[1])
            end
        end
    end

    self.renderer:UpdateFill(pct, r, g, b)
    self.renderer:UpdateTexts(t)
end

-- Internal: subscribe/unsubscribe to update cadence based on settings
function CastBarSlot:GetDesiredEvent()
    local rate = ns.Settings:Get("castUpdateRate")
    if rate == "normal" then
        return "Update" -- ~95ms
    else
        return "UpdateSemiFrequent" -- ~45ms (default)
    end
end

function CastBarSlot:Subscribe()
    local desired = self:GetDesiredEvent()
    if self.updateEvent == desired then return end
    self:Unsubscribe()
    ns.TrackerHelper.events:On(desired, self, self.UpdateCastFill)
    self.updateEvent = desired
end

function CastBarSlot:Unsubscribe()
    if self.updateEvent then
        ns.TrackerHelper.events:Off(self.updateEvent, self, self.UpdateCastFill)
        self.updateEvent = nil
    end
end

-- Public: resubscribe when settings change
function CastBarSlot:Resubscribe()
    if not self.isActive then return end
    self:Subscribe()
end
