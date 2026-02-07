local ADDON_NAME, ns = ...

local SlotBase = ns.CreateClass(nil, {})
ns.SlotBase = SlotBase

function SlotBase:New()
    local o = SlotBase.__index.New(self)
    o.tracker = nil
    o.isActive = false
    o.bindings = {} -- { event, obj, func } for cleanup
    return o
end

function SlotBase:BindTracker(tracker, events)
    self.tracker = tracker
    if not events then return end
    for event, func in pairs(events) do
        tracker.events:On(event, self, func)
        self.bindings[#self.bindings + 1] = { tracker.events, event, self, func }
    end
end

function SlotBase:UnbindTracker()
    for _, b in ipairs(self.bindings) do
        b[1]:Off(b[2], b[3], b[4])
    end
    self.bindings = {}
    self.tracker = nil
end

function SlotBase:Activate()
    self.isActive = true
end

function SlotBase:Deactivate()
    self.isActive = false
    self:UnbindTracker()
end

function SlotBase:OnDataChanged()
    -- Override in subclasses
end
