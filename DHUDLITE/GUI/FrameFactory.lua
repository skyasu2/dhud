local ADDON_NAME, ns = ...

local FrameFactory = {}
ns.FrameFactory = FrameFactory

local Textures = ns.Textures

-- Store all created frames
FrameFactory.frames = {}
FrameFactory.frameGroups = {}

function FrameFactory:CreateFrame(name, parent, pointThis, pointParent, offX, offY, w, h, strata, frameType)
    strata = strata or "BACKGROUND"
    frameType = frameType or "Frame"
    local parentFrame = type(parent) == "string" and _G[parent] or parent
    local frame = CreateFrame(frameType, name, parentFrame)
    frame:SetPoint(pointThis, parentFrame, pointParent, offX, offY)
    frame:SetWidth(w)
    frame:SetHeight(h)
    frame:EnableMouse(false)
    frame:SetFrameStrata(strata)
    frame.relativeInfo = { pointThis, parent, pointParent, offX, offY }
    if name then
        self.frames[name] = frame
    end
    return frame
end

function FrameFactory:CreateTextureFrame(name, parent, pointThis, pointParent, offX, offY, w, h, textureName, mirror, layer)
    layer = layer or "BACKGROUND"
    local frame = self:CreateFrame(name, parent, pointThis, pointParent, offX, offY, w, h)
    local info = Textures.list[textureName]
    local path = self.ResolvePath(info[1])
    local x0, x1, y0, y1 = info[2], info[3], info[4], info[5]
    if mirror then
        x0, x1 = x1, x0
    end
    local texture = frame:CreateTexture(name and (name .. "_tex") or nil, layer)
    texture:SetTexture(path)
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    texture:SetTexCoord(x0, x1, y0, y1)
    frame.texture = texture
    texture.frame = frame
    return frame, texture
end

function FrameFactory:CreateBarFrame(name, parent, pointThis, pointParent, offX, offY, w, h, textureName, mirror)
    local frame, texture = self:CreateTextureFrame(name, parent, pointThis, pointParent, offX, offY, w, h, textureName, mirror)
    local style = ns.Settings:Get("barsTexture") or 2
    texture.pathPrefix = Textures.list[textureName][1]
    local path = self.ResolvePath((texture.pathPrefix or "") .. tostring(style))
    texture:SetTexture(path)
    if not texture:GetTexture() then
        -- Fallback to a solid texture so fills are visible even if art fails to load
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
    return frame, texture
end

function FrameFactory:CreateTextFontString(frame, varName, pointThis, pointParent, offX, offY, w, h, alignH, alignV, fontType, fontLayer)
    fontType = fontType or "default"
    fontLayer = fontLayer or "ARTWORK"
    local autoresize = (w == nil)
    w = w or 200
    local fontName = Textures.fonts[fontType]
    local outline = Textures.FONT_OUTLINES[(ns.Settings:Get("fontOutline") or 0) + 1] or ""
    local fontSize = ns.Settings:Get("fontSizeBars") or 10
    local tf = frame:CreateFontString(frame:GetName() and (frame:GetName() .. "_" .. varName) or nil, fontLayer)
    tf.fontName = fontName
    tf:SetFont(fontName, fontSize, outline)
    tf:SetJustifyH(alignH)
    tf:SetJustifyV(alignV)
    tf:SetWidth(w)
    tf:SetHeight(h)
    tf:SetPoint(pointThis, frame, pointParent, offX, offY)
    frame[varName] = tf
    tf.frame = frame
    if autoresize then
        tf.DSetText = function(self, text)
            self:SetWidth(1000)
            self:SetText(text or "")
            local sw = self:GetStringWidth() or 0
            -- Secret value text produces secret GetStringWidth; SetWidth rejects it
            if issecretvalue and issecretvalue(sw) then
                sw = 150
            end
            self:SetWidth(sw)
            if self.frame and self.frame.resizeWithTextField then
                self.frame:SetWidth(sw)
            end
        end
    else
        tf.DSetText = tf.SetText
    end
    return tf
end

function FrameFactory:CreateTextFrame(name, parent, pointThis, pointParent, offX, offY, w, h, alignH, alignV, fontType, fontLayer)
    local autoresize = (w == nil)
    local frame = self:CreateFrame(name, parent, pointThis, pointParent, offX, offY, w or 200, h)
    frame.resizeWithTextField = autoresize
    local tf = self:CreateTextFontString(frame, "textField", "CENTER", "CENTER", 0, 0, w, h, alignH, alignV, fontType, fontLayer)
    return frame, tf
end

function FrameFactory:CreateComboPointFrame(name)
    local frame = self:CreateTextureFrame(name, "DHUDLITE_UIParent", "CENTER", "CENTER", 0, 0, 20, 20, "ComboCircleRed", false)
    return frame
end

function FrameFactory:CreateRuneFrame(name)
    local frame, texture = self:CreateTextureFrame(name, "DHUDLITE_UIParent", "CENTER", "CENTER", 0, 0, 30, 30, "BlizzardDKRuneDeath", false)
    self:CreateTextFontString(frame, "textFieldTime", "CENTER", "CENTER", 0, 0, 60, 30, "CENTER", "MIDDLE", "default", "OVERLAY")
    return frame
end

function FrameFactory:CreateIconFrame(name, parent, pointThis, pointParent, offX, offY, w, h, textureName)
    local frame = self:CreateTextureFrame(name, parent, pointThis, pointParent, offX, offY, w, h, textureName)
    return frame
end

-- Dynamic frame group with auto-creation
function FrameFactory:CreateDynamicGroup(groupName, createFunc, limit)
    local group = {}
    group.framesShown = 0
    group.limit = limit
    local mt = {}
    mt.__index = function(list, key)
        if type(key) ~= "number" then return nil end
        if key > limit then return group[limit] end
        local frame = createFunc(key)
        group[key] = frame
        for i = group.framesShown + 1, key - 1 do
            if group[i] then group[i]:Show() end
        end
        group.framesShown = key
        return frame
    end
    setmetatable(group, mt)
    function group:SetFramesShown(count)
        if self.framesShown == count then return end
        for i = self.framesShown + 1, count do
            if self[i] then self[i]:Show() end
        end
        for i = self.framesShown, count + 1, -1 do
            if rawget(self, i) then self[i]:Hide() end
        end
        self.framesShown = count
    end
    self.frameGroups[groupName] = group
    return group
end
-- Helper: resolve texture path, appending .tga for addon art assets
function FrameFactory.ResolvePath(path)
    if type(path) ~= "string" then return path end
    if path:find("Interface\\AddOns\\DHUDLITE\\art\\", 1, true) and not path:match("%.[%a%d]+$") then
        return path .. ".tga"
    end
    return path
end
