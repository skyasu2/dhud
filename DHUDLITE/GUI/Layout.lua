local ADDON_NAME, ns = ...

local Layout = {}
ns.Layout = Layout

local FF = ns.FrameFactory
local Textures = ns.Textures

-- Position constants matching DHUD
local BAR_WIDTH = 128
local BAR_HEIGHT = 256

function Layout:CreateFrames()
    local scale = ns.Settings:Get("scaleMain") or 1.0
    local dist = ns.Settings:Get("barsDistanceDiv2") or 0

    -- Root frame
    local root = FF:CreateFrame("DHUDLITE_UIParent", UIParent, "CENTER", "CENTER", 0, 0, BAR_WIDTH * 2 + 100, BAR_HEIGHT, "BACKGROUND")
    root:SetScale(scale)
    -- Store reference
    self.root = root

    -- Left bars background
    local leftBg = FF:CreateFrame("DHUDLITE_Left_BarsBackground", "DHUDLITE_UIParent", "RIGHT", "CENTER", -dist, 0, BAR_WIDTH, BAR_HEIGHT)

    -- Right bars background
    local rightBg = FF:CreateFrame("DHUDLITE_Right_BarsBackground", "DHUDLITE_UIParent", "LEFT", "CENTER", dist, 0, BAR_WIDTH, BAR_HEIGHT)

    -- Background textures (will be updated dynamically)
    self:CreateBackgroundTexture("left")
    self:CreateBackgroundTexture("right")

    -- Left bar groups (dynamic, auto-create on demand)
    self.leftBig1 = FF:CreateDynamicGroup("leftBig1", function(index)
        return FF:CreateBarFrame("DHUDLITE_Left_BarBig1_" .. index, "DHUDLITE_Left_BarsBackground",
            "BOTTOM", "BOTTOM", 0, 0, BAR_WIDTH, BAR_HEIGHT, "TexturePrefixBarB1")
    end, 6)

    self.leftBig2 = FF:CreateDynamicGroup("leftBig2", function(index)
        return FF:CreateBarFrame("DHUDLITE_Left_BarBig2_" .. index, "DHUDLITE_Left_BarsBackground",
            "BOTTOM", "BOTTOM", 0, 0, BAR_WIDTH, BAR_HEIGHT, "TexturePrefixBarB2")
    end, 6)

    self.leftSmall1 = FF:CreateDynamicGroup("leftSmall1", function(index)
        return FF:CreateBarFrame("DHUDLITE_Left_BarSmall1_" .. index, "DHUDLITE_Left_BarsBackground",
            "BOTTOM", "BOTTOM", 0, 0, BAR_WIDTH, BAR_HEIGHT, "TexturePrefixBarS1")
    end, 3)

    self.leftSmall2 = FF:CreateDynamicGroup("leftSmall2", function(index)
        return FF:CreateBarFrame("DHUDLITE_Left_BarSmall2_" .. index, "DHUDLITE_Left_BarsBackground",
            "BOTTOM", "BOTTOM", 0, 0, BAR_WIDTH, BAR_HEIGHT, "TexturePrefixBarS2")
    end, 3)

    -- Right bar groups (mirrored)
    self.rightBig1 = FF:CreateDynamicGroup("rightBig1", function(index)
        return FF:CreateBarFrame("DHUDLITE_Right_BarBig1_" .. index, "DHUDLITE_Right_BarsBackground",
            "BOTTOM", "BOTTOM", 0, 0, BAR_WIDTH, BAR_HEIGHT, "TexturePrefixBarB1", true)
    end, 6)

    self.rightBig2 = FF:CreateDynamicGroup("rightBig2", function(index)
        return FF:CreateBarFrame("DHUDLITE_Right_BarBig2_" .. index, "DHUDLITE_Right_BarsBackground",
            "BOTTOM", "BOTTOM", 0, 0, BAR_WIDTH, BAR_HEIGHT, "TexturePrefixBarB2", true)
    end, 6)

    self.rightSmall1 = FF:CreateDynamicGroup("rightSmall1", function(index)
        return FF:CreateBarFrame("DHUDLITE_Right_BarSmall1_" .. index, "DHUDLITE_Right_BarsBackground",
            "BOTTOM", "BOTTOM", 0, 0, BAR_WIDTH, BAR_HEIGHT, "TexturePrefixBarS1", true)
    end, 3)

    self.rightSmall2 = FF:CreateDynamicGroup("rightSmall2", function(index)
        return FF:CreateBarFrame("DHUDLITE_Right_BarSmall2_" .. index, "DHUDLITE_Right_BarsBackground",
            "BOTTOM", "BOTTOM", 0, 0, BAR_WIDTH, BAR_HEIGHT, "TexturePrefixBarS2", true)
    end, 3)

    -- Pre-create dynamic bar segments BEFORE text frames so text renders on top
    self:WarmupBarGroups()

    -- Text frames for bar values (left side)
    self.leftBig1Text = FF:CreateTextFrame("DHUDLITE_Left_TextBig1", "DHUDLITE_Left_BarsBackground",
        "LEFT", "BOTTOM", 60, 5, nil, 14, "LEFT", "MIDDLE", "numeric")
    self.leftBig2Text = FF:CreateTextFrame("DHUDLITE_Left_TextBig2", "DHUDLITE_Left_BarsBackground",
        "LEFT", "BOTTOM", 25, 5, nil, 14, "LEFT", "MIDDLE", "numeric")
    self.leftSmall1Text = FF:CreateTextFrame("DHUDLITE_Left_TextSmall1", "DHUDLITE_Left_BarsBackground",
        "LEFT", "BOTTOM", 5, 5, nil, 14, "LEFT", "MIDDLE", "numeric")
    self.leftSmall2Text = FF:CreateTextFrame("DHUDLITE_Left_TextSmall2", "DHUDLITE_Left_BarsBackground",
        "LEFT", "BOTTOM", -10, 5, nil, 14, "LEFT", "MIDDLE", "numeric")

    -- Text frames for bar values (right side)
    self.rightBig1Text = FF:CreateTextFrame("DHUDLITE_Right_TextBig1", "DHUDLITE_Right_BarsBackground",
        "RIGHT", "BOTTOM", -60, 5, nil, 14, "RIGHT", "MIDDLE", "numeric")
    self.rightBig2Text = FF:CreateTextFrame("DHUDLITE_Right_TextBig2", "DHUDLITE_Right_BarsBackground",
        "RIGHT", "BOTTOM", -25, 5, nil, 14, "RIGHT", "MIDDLE", "numeric")
    self.rightSmall1Text = FF:CreateTextFrame("DHUDLITE_Right_TextSmall1", "DHUDLITE_Right_BarsBackground",
        "RIGHT", "BOTTOM", -5, 5, nil, 14, "RIGHT", "MIDDLE", "numeric")
    self.rightSmall2Text = FF:CreateTextFrame("DHUDLITE_Right_TextSmall2", "DHUDLITE_Right_BarsBackground",
        "RIGHT", "BOTTOM", 10, 5, nil, 14, "RIGHT", "MIDDLE", "numeric")

    -- Ensure text frames render above bar textures
    local textFrames = {
        self.leftBig1Text, self.leftBig2Text, self.leftSmall1Text, self.leftSmall2Text,
        self.rightBig1Text, self.rightBig2Text, self.rightSmall1Text, self.rightSmall2Text,
    }
    for _, tf in ipairs(textFrames) do
        if tf and tf.SetFrameLevel then
            tf:SetFrameLevel(tf:GetFrameLevel() + 10)
        end
    end

    -- Cast bar frames (left = player, right = target)
    self:CreateCastBarFrames("left")
    self:CreateCastBarFrames("right")

    -- Center text frames (unit info)
    self.centerText1 = FF:CreateTextFrame("DHUDLITE_Center_TextInfo1", "DHUDLITE_UIParent",
        "CENTER", "CENTER", 0, -BAR_HEIGHT / 2 - 5, nil, 14, "CENTER", "TOP")
    self.centerText2 = FF:CreateTextFrame("DHUDLITE_Center_TextInfo2", "DHUDLITE_UIParent",
        "CENTER", "CENTER", 0, -BAR_HEIGHT / 2 - 20, nil, 14, "CENTER", "TOP")

    -- Icon frames
    self:CreateIconFrames()

    -- Combo point / resource frames
    self:CreateResourceFrames()

    -- React to setting changes
    ns.Settings:OnChange("barsDistanceDiv2", self, function(_, key, value)
        self:SetBarsDistance(value or 0)
    end)
    ns.Settings:OnChange("barsTexture", self, function(_, key, value)
        self:RefreshBarStyles()
    end)
    ns.Settings:OnChange("showBackground", self, function()
        self:RefreshBackgrounds()
    end)
    ns.Settings:OnChange("fontOutline", self, function()
        self:RefreshFonts()
    end)
    ns.Settings:OnChange("fontSizeBars", self, function()
        self:RefreshFonts()
    end)
    ns.Settings:OnChange("fontSizeInfo", self, function()
        self:RefreshFonts()
    end)
    ns.Settings:OnChange("fontSizeCast", self, function()
        self:RefreshFonts()
    end)
end

function Layout:CreateBackgroundTexture(side)
    local parent = (side == "left") and "DHUDLITE_Left_BarsBackground" or "DHUDLITE_Right_BarsBackground"
    local name = "DHUDLITE_" .. (side == "left" and "Left" or "Right") .. "_Background"
    local mirror = (side == "right")
    -- Default: show 1 big inner bar background
    local texName = "BackgroundBars1BI0S"
    local frame, texture = FF:CreateTextureFrame(name, parent, "BOTTOM", "BOTTOM", 0, 0, BAR_WIDTH, BAR_HEIGHT, texName, mirror)
    if side == "left" then
        self.leftBgFrame = frame
        self.leftBgTexture = texture
    else
        self.rightBgFrame = frame
        self.rightBgTexture = texture
    end
end

function Layout:UpdateBackground(side, mask)
    local tex, mirror
    if side == "left" then
        tex = self.leftBgTexture
        mirror = false
    else
        tex = self.rightBgTexture
        mirror = true
    end
    if not tex then return end
    -- Determine background texture from mask
    -- mask bits: 1=Big1, 2=Big2, 4=Small1, 8=Small2
    local texName
    if mask == 0 then
        texName = "BackgroundBars0B0S"
    elseif mask == 1 then
        texName = "BackgroundBars1BI0S"
    elseif mask == 5 then
        texName = "BackgroundBars1BI1SI"
    elseif mask == 2 then
        texName = "BackgroundBars1BO0S"
    elseif mask == 3 then
        texName = "BackgroundBars2B0S"
    elseif mask == 7 then
        texName = "BackgroundBars2B1SI"
    elseif mask == 15 then
        texName = "BackgroundBars2B2S"
    else
        texName = "BackgroundBars2B0S"
    end

    local info = Textures.list[texName]
    if not info then return end
    tex:SetTexture(info[1])
    local x0, x1, y0, y1 = info[2], info[3], info[4], info[5]
    if mirror then x0, x1 = x1, x0 end
    tex:SetTexCoord(x0, x1, y0, y1)
end

function Layout:CreateCastBarFrames(side)
    local prefix = (side == "left") and "DHUDLITE_Left" or "DHUDLITE_Right"
    local parent = prefix .. "_BarsBackground"
    local mirror = (side == "right")
    local textAlign = (side == "left") and "LEFT" or "RIGHT"
    local textOffX = (side == "left") and 60 or -60
    local iconOffX = (side == "left") and 60 or -60
    local timeOffX = (side == "left") and 30 or -30
    local texName = "CastingBarB1"
    local flashTexName = "CastFlashBarB1"

    local castFrame = FF:CreateCastBarFrame(prefix .. "_CastBar", parent,
        "BOTTOM", "BOTTOM", 0, 0, BAR_WIDTH, BAR_HEIGHT, texName, mirror)
    local flashFrame = FF:CreateCastBarFrame(prefix .. "_CastFlash", parent,
        "BOTTOM", "BOTTOM", 0, 0, BAR_WIDTH, BAR_HEIGHT, flashTexName, mirror)
    local iconFrame = FF:CreateCastBarIconFrame(prefix .. "_CastIcon", parent,
        "BOTTOM", "BOTTOM", iconOffX, 275, 30, 30)
    local spellNameFrame = FF:CreateTextFrame(prefix .. "_CastSpellText", parent,
        textAlign, "BOTTOM", textOffX + 19, 290, nil, 14, textAlign, "MIDDLE")
    local castTimeFrame = FF:CreateTextFrame(prefix .. "_CastTimeText", parent,
        textAlign, "BOTTOM", timeOffX, 252, 100, 14, textAlign, "MIDDLE")
    local delayFrame = FF:CreateTextFrame(prefix .. "_CastDelayText", parent,
        textAlign, "BOTTOM", timeOffX, 266, 100, 14, textAlign, "MIDDLE")

    -- Hide all initially
    castFrame:Hide()
    flashFrame:Hide()
    iconFrame:Hide()
    spellNameFrame:Hide()
    castTimeFrame:Hide()
    delayFrame:Hide()

    if side == "left" then
        self.leftCastFrames = { castFrame, flashFrame, iconFrame, spellNameFrame, castTimeFrame, delayFrame }
    else
        self.rightCastFrames = { castFrame, flashFrame, iconFrame, spellNameFrame, castTimeFrame, delayFrame }
    end
end

function Layout:CreateIconFrames()
    -- PvP icon
    self.pvpIcon = FF:CreateIconFrame("DHUDLITE_Icon_PvP", "DHUDLITE_Left_BarsBackground",
        "TOP", "TOP", 50, -15, 30, 30, "BlizzardPvPHorde")
    self.pvpIcon:Hide()

    -- Combat/resting state icon
    self.stateIcon = FF:CreateIconFrame("DHUDLITE_Icon_State", "DHUDLITE_Left_BarsBackground",
        "TOP", "TOP", 42, 12, 30, 30, "BlizzardPlayerInCombat")
    self.stateIcon:Hide()

    -- Elite dragon
    self.eliteIcon = FF:CreateIconFrame("DHUDLITE_Icon_Elite", "DHUDLITE_Right_BarsBackground",
        "TOP", "TOP", -18, 20, 60, 60, "TargetEliteDragon")
    self.eliteIcon.texture:SetTexCoord(1, 0, 0, 1) -- Mirror for right side
    self.eliteIcon:Hide()

    -- Raid target icon
    self.raidIcon = FF:CreateIconFrame("DHUDLITE_Icon_RaidTarget", "DHUDLITE_Center_TextInfo1",
        "BOTTOM", "TOP", 0, 2, 25, 25, "BlizzardRaidIcon1")
    self.raidIcon:Hide()
end

-- Create all possible dynamic bar frames up-front to minimize taint/perf spikes
function Layout:WarmupBarGroups()
    local groups = {
        { self.leftBig1,   6 }, { self.leftBig2,   6 },
        { self.leftSmall1, 3 }, { self.leftSmall2, 3 },
        { self.rightBig1,  6 }, { self.rightBig2,  6 },
        { self.rightSmall1,3 }, { self.rightSmall2,3 },
    }
    for _, pair in ipairs(groups) do
        local group, limit = pair[1], pair[2]
        if group then
            -- Touch the highest index to force creation of all frames up to limit
            local _ = group[limit]
            -- Hide them by default; they will be shown by renderer
            if group.SetFramesShown then group:SetFramesShown(0) end
        end
    end
end

function Layout:CreateResourceFrames()
    local resourceScale = ns.Settings:Get("scaleResources") or 1.0
    -- Combo points (max 10 for safety)
    self.comboFrames = {}
    for i = 1, 10 do
        local frame = FF:CreateComboPointFrame("DHUDLITE_Combo_" .. i)
        frame:SetScale(resourceScale)
        frame:Hide()
        self.comboFrames[i] = frame
    end

    -- DK Runes (6)
    self.runeFrames = {}
    for i = 1, 6 do
        local frame = FF:CreateRuneFrame("DHUDLITE_Rune_" .. i)
        frame:SetScale(resourceScale)
        frame:Hide()
        self.runeFrames[i] = frame
    end
end

function Layout:GetBarGroup(slotName)
    return FF.frameGroups[slotName]
end

function Layout:GetTextFrame(slotName)
    local map = {
        leftBig1 = self.leftBig1Text,
        leftBig2 = self.leftBig2Text,
        leftSmall1 = self.leftSmall1Text,
        leftSmall2 = self.leftSmall2Text,
        rightBig1 = self.rightBig1Text,
        rightBig2 = self.rightBig2Text,
        rightSmall1 = self.rightSmall1Text,
        rightSmall2 = self.rightSmall2Text,
    }
    return map[slotName]
end

function Layout:GetBarParent(slotName)
    if slotName:find("^left") then
        return FF.frames["DHUDLITE_Left_BarsBackground"]
    else
        return FF.frames["DHUDLITE_Right_BarsBackground"]
    end
end

function Layout:SetVisible(visible)
    local root = FF.frames["DHUDLITE_UIParent"]
    if root then
        if visible then
            root:Show()
        else
            root:Hide()
        end
    end
end

function Layout:SetAlpha(alpha)
    local root = FF.frames["DHUDLITE_UIParent"]
    if root then
        root:SetAlpha(alpha)
    end
end

-- Set alpha for a side's bar background group independently (multiplies with root alpha)
function Layout:SetSideAlpha(side, alpha)
    local frame
    if side == "left" then
        frame = FF.frames["DHUDLITE_Left_BarsBackground"]
    else
        frame = FF.frames["DHUDLITE_Right_BarsBackground"]
    end
    if frame then
        frame:SetAlpha(alpha or 1)
    end
end

-- Recalculate and apply backgrounds based on current settings
function Layout:RefreshBackgrounds()
    local Settings = ns.Settings
    local function maskFor(side)
        local mask = 0
        if (Settings:Get(side .. "Big1") or "") ~= "" then mask = mask + 1 end
        if (Settings:Get(side .. "Big2") or "") ~= "" then mask = mask + 2 end
        if (Settings:Get(side .. "Small1") or "") ~= "" then mask = mask + 4 end
        if (Settings:Get(side .. "Small2") or "") ~= "" then mask = mask + 8 end
        return mask
    end
    local show = Settings:Get("showBackground") and true or false
    local leftMask = show and maskFor("left") or 0
    local rightMask = show and maskFor("right") or 0
    self:UpdateBackground("left", leftMask)
    self:UpdateBackground("right", rightMask)
end

-- Update left/right bar background offsets from center
function Layout:SetBarsDistance(dist)
    dist = tonumber(dist) or 0
    local left = FF.frames["DHUDLITE_Left_BarsBackground"]
    local right = FF.frames["DHUDLITE_Right_BarsBackground"]
    local parent = FF.frames["DHUDLITE_UIParent"]
    if left and parent then
        left:ClearAllPoints()
        left:SetPoint("RIGHT", parent, "CENTER", -dist, 0)
    end
    if right and parent then
        right:ClearAllPoints()
        right:SetPoint("LEFT", parent, "CENTER", dist, 0)
    end
end

-- Apply current bar texture style to all created bar frames
function Layout:RefreshBarStyles()
    local style = ns.Settings:Get("barsTexture") or 1
    local groups = { self.leftBig1, self.leftBig2, self.leftSmall1, self.leftSmall2,
                     self.rightBig1, self.rightBig2, self.rightSmall1, self.rightSmall2 }
    for _, group in ipairs(groups) do
        if group then
            for i = 1, (group.framesShown or 0) do
                local frame = rawget(group, i)
                if frame and frame.texture and frame.texture.pathPrefix then
                    local path = ns.FrameFactory.ResolvePath((frame.texture.pathPrefix or "") .. tostring(style))
                    frame.texture:SetTexture(path)
                    if not frame.texture:GetTexture() then
                        frame.texture:SetTexture("Interface\\Buttons\\WHITE8X8")
                    end
                end
            end
        end
    end
end

-- Update fonts for known text elements
function Layout:RefreshFonts()
    local outline = ns.Textures.FONT_OUTLINES[(ns.Settings:Get("fontOutline") or 0) + 1] or ""
    local fontBars = ns.Textures.fonts["numeric"]
    local sizeBars = ns.Settings:Get("fontSizeBars") or 10
    local sizeInfo = ns.Settings:Get("fontSizeInfo") or 10
    local sizeCast = ns.Settings:Get("fontSizeCast") or 10
    local function set(fs, size)
        if fs and fs.SetFont then fs:SetFont(fontBars, size, outline) end
    end
    -- Bar values
    if self.leftBig1Text then set(self.leftBig1Text.textField, sizeBars) end
    if self.leftBig2Text then set(self.leftBig2Text.textField, sizeBars) end
    if self.leftSmall1Text then set(self.leftSmall1Text.textField, sizeBars) end
    if self.leftSmall2Text then set(self.leftSmall2Text.textField, sizeBars) end
    if self.rightBig1Text then set(self.rightBig1Text.textField, sizeBars) end
    if self.rightBig2Text then set(self.rightBig2Text.textField, sizeBars) end
    if self.rightSmall1Text then set(self.rightSmall1Text.textField, sizeBars) end
    if self.rightSmall2Text then set(self.rightSmall2Text.textField, sizeBars) end
    -- Center info
    if self.centerText1 then set(self.centerText1.textField, sizeInfo) end
    if self.centerText2 then set(self.centerText2.textField, sizeInfo) end
    -- Cast bars
    if self.leftCastFrames then
        local _, _, _, nameF, timeF, delayF = unpack(self.leftCastFrames)
        if nameF and nameF.textField then set(nameF.textField, sizeCast) end
        if timeF and timeF.textField then set(timeF.textField, sizeCast) end
        if delayF and delayF.textField then set(delayF.textField, sizeCast) end
    end
    if self.rightCastFrames then
        local _, _, _, nameF, timeF, delayF = unpack(self.rightCastFrames)
        if nameF and nameF.textField then set(nameF.textField, sizeCast) end
        if timeF and timeF.textField then set(timeF.textField, sizeCast) end
        if delayF and delayF.textField then set(delayF.textField, sizeCast) end
    end
end

-- Toggle drag/move mode for the root frame
function Layout:SetMovable(enabled)
    local root = self.root or FF.frames["DHUDLITE_UIParent"]
    if not root then return end
    root:EnableMouse(enabled and true or false)
    root:SetMovable(enabled and true or false)
    if enabled then
        root:RegisterForDrag("LeftButton")
        root:SetScript("OnDragStart", function(f) f:StartMoving() end)
        root:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
        -- overlay
        if not self.moveOverlay then
            local ov = root:CreateTexture(nil, "OVERLAY")
            ov:SetAllPoints(true)
            ov:SetColorTexture(0, 1, 0, 0.1)
            self.moveOverlay = ov
        end
        self.moveOverlay:Show()
    else
        root:RegisterForDrag()
        root:SetScript("OnDragStart", nil)
        root:SetScript("OnDragStop", nil)
        if self.moveOverlay then self.moveOverlay:Hide() end
    end
end

function Layout:ResetPosition()
    local root = self.root or FF.frames["DHUDLITE_UIParent"]
    if not root then return end
    root:ClearAllPoints()
    root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end
