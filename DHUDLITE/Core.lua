--[[-----------------------------------------------------------------------------------
 DHUD Lite - Lightweight HUD for WoW 12.0.0
 Based on DHUD by MADCAT (MIT License)
 Designed for Secret Values compatibility
-----------------------------------------------------------------------------------]]--

local ADDON_NAME, ns = ...

-- Simplified class system
function ns.CreateClass(parent, fields)
    local c = fields or {}
    c.__index = c
    c.super = parent
    if parent then
        setmetatable(c, parent)
    end
    function c:New(o)
        o = o or {}
        setmetatable(o, self)
        return o
    end
    return c
end

-- Lightweight EventBus
local EventBus = {}
EventBus.__index = EventBus

function EventBus:New()
    return setmetatable({ listeners = {} }, EventBus)
end

function EventBus:On(event, obj, func)
    local list = self.listeners[event]
    if not list then
        list = {}
        self.listeners[event] = list
    end
    list[#list + 1] = { obj = obj, fn = func }
end

function EventBus:Off(event, obj, func)
    local list = self.listeners[event]
    if not list then return end
    for i = #list, 1, -1 do
        local entry = list[i]
        if entry and entry.obj == obj and entry.fn == func then
            table.remove(list, i)
            return
        end
    end
end

function EventBus:Fire(event, ...)
    local list = self.listeners[event]
    if not list then return end
    -- Snapshot length so Off() during iteration doesn't skip entries
    local n = #list
    for i = 1, n do
        local entry = list[i]
        if entry then
            entry.fn(entry.obj, ...)
        end
    end
end

ns.EventBus = EventBus

-- Global addon event bus
ns.events = EventBus:New()

-- Utility: create a Blizzard event frame
function ns.CreateEventFrame()
    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(self, event, ...)
        local func = self[event]
        if func then func(self, ...) end
    end)
    return frame
end

-- Print helper
function ns.Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88DHUDLITE:|r " .. (msg or "nil"), 1, 1, 1)
    end
end
