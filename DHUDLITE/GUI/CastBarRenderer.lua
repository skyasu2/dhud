local ADDON_NAME, ns = ...

local CastBarRenderer = ns.CreateClass(nil, {})
ns.CastBarRenderer = CastBarRenderer

local CT = ns.CastTracker

function CastBarRenderer:New(clippingId, side)
    local o = setmetatable({}, self)
    o.side = side
    o.castFrame = nil
    o.flashFrame = nil
    o.iconFrame = nil
    o.spellNameField = nil
    o.castTimeField = nil
    o.delayField = nil
    o.empowerFrames = {}
    o.isFlashing = false
    o.flashAlpha = 0
    o.processingUpdates = false

    local clip = ns.Textures:GetClipping(clippingId)
    local texInfo = ns.Textures.list[clippingId]
    o.pixelsHeight = clip[1]
    o.fromTopPct = clip[2] / clip[1]
    o.fromBotPct = clip[3] / clip[1]
    o.realHeightPct = (clip[1] - clip[2] - clip[3]) / clip[1]
    if side == "left" then
        o.texX1 = texInfo[2]
        o.texX2 = texInfo[3]
    else
        o.texX1 = texInfo[3]
        o.texX2 = texInfo[2]
    end

    return o
end

function CastBarRenderer:SetFrames(castFrame, flashFrame, iconFrame, spellNameFrame, castTimeFrame, delayFrame, parentFrame)
    self.castFrame = castFrame
    self.flashFrame = flashFrame
    self.iconFrame = iconFrame
    self.spellNameField = spellNameFrame and spellNameFrame.textField
    self.castTimeField = castTimeFrame and castTimeFrame.textField
    self.delayField = delayFrame and delayFrame.textField
    self.parentFrame = parentFrame
end

function CastBarRenderer:UpdateFill(pct, r, g, b)
    if not self.castFrame then return end
    local tex = self.castFrame.texture
    if not tex then return end

    local h = self.realHeightPct * self.pixelsHeight * pct
    if h <= 0 then h = 0.01 end

    local texBot = self.fromBotPct
    local texTop = 1 - self.fromTopPct - (self.realHeightPct * (1 - pct))
    local offsetY = self.pixelsHeight * texBot

    tex:SetHeight(h)
    tex:SetTexCoord(self.texX1, self.texX2, 1 - texTop, 1 - texBot)
    tex:ClearAllPoints()
    tex:SetPoint("BOTTOM", self.parentFrame, "BOTTOM", 0, offsetY)
    tex:SetVertexColor(r, g, b)
end

function CastBarRenderer:ShowCast(tracker)
    if not self.castFrame then return end
    self.castFrame:Show()
    if self.iconFrame then
        self.iconFrame:Show()
        if tracker.spellIcon and tracker.spellIcon ~= "" then
            self.iconFrame:SetNormalTexture(tracker.spellIcon)
        end
    end
    if self.spellNameField then
        self.spellNameField:DSetText(tracker.spellName or "")
        self.spellNameField.frame:Show()
    end
    if self.castTimeField then
        self.castTimeField.frame:Show()
    end
    if self.delayField then
        self.delayField.frame:Show()
    end
    self:SetUpdatesRequired(true)
end

function CastBarRenderer:HideCast()
    if self.castFrame then self.castFrame:Hide() end
    if self.flashFrame then self.flashFrame:Hide() end
    if self.iconFrame then self.iconFrame:Hide() end
    if self.spellNameField then self.spellNameField.frame:Hide() end
    if self.castTimeField then self.castTimeField.frame:Hide() end
    if self.delayField then self.delayField.frame:Hide() end
    for _, f in ipairs(self.empowerFrames) do
        f:Hide()
    end
    self:SetUpdatesRequired(false)
end

function CastBarRenderer:StartFlash()
    if not self.flashFrame then return end
    self.isFlashing = true
    self.flashAlpha = 1
    self.flashFrame:Show()
    self.flashFrame.texture:SetAlpha(1)
end

function CastBarRenderer:UpdateFlash(elapsed)
    if not self.isFlashing then return end
    self.flashAlpha = self.flashAlpha - elapsed * 3
    if self.flashAlpha <= 0 then
        self.flashAlpha = 0
        self.isFlashing = false
        if self.flashFrame then self.flashFrame:Hide() end
        return
    end
    if self.flashFrame and self.flashFrame.texture then
        self.flashFrame.texture:SetAlpha(self.flashAlpha)
    end
end

function CastBarRenderer:UpdateTexts(tracker)
    if not tracker or not tracker.endTime then return end
    local remaining = tracker.endTime - GetTime()
    if remaining < 0 then remaining = 0 end

    if self.castTimeField then
        self.castTimeField:DSetText(ns.TextFormat:FormatCastTime(remaining))
    end

    if self.delayField then
        if tracker.delay and tracker.delay > 0.1 then
            self.delayField:DSetText(string.format("+%.1f", tracker.delay))
        else
            self.delayField:DSetText("")
        end
    end
end

function CastBarRenderer:SetUpdatesRequired(required)
    if self.processingUpdates == required then return end
    self.processingUpdates = required
    if required then
        ns.TrackerHelper.events:On("UpdateFrequent", self, self.OnUpdateTime)
    else
        ns.TrackerHelper.events:Off("UpdateFrequent", self, self.OnUpdateTime)
    end
end

function CastBarRenderer:OnUpdateTime(elapsed)
    self:UpdateFlash(elapsed or 0.016)
end
