local ADDON_NAME, ns = ...

local settingsCategory -- new Settings API category
local built = false
-- Metadata helper (11.0+ uses C_AddOns.GetAddOnMetadata)
local function GetMeta(addon, field)
    if _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata then
        return _G.C_AddOns.GetAddOnMetadata(addon, field)
    elseif _G.GetAddOnMetadata then
        return _G.GetAddOnMetadata(addon, field)
    end
    return nil
end

-- Build UI controls lazily to avoid load-order issues
local function BuildControls(panel)
    if built then return end
    built = true

    -- Create ScrollFrame to handle overflowing content
    local scrollFrame = CreateFrame("ScrollFrame", "DHUDLITE_OptionsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    -- Create Content Frame (Child)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollFrame:GetWidth(), 3500)
    scrollFrame:SetScrollChild(content)

    local isRefreshing = false

    -- ============================================================
    -- Factory helpers
    -- ============================================================
    local function createSectionHeader(text, anchor, yOff)
        local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff or -20)
        header:SetText("|cffffcc00" .. text .. "|r")
        local line = content:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
        line:SetPoint("RIGHT", content, "RIGHT", -16, 0)
        line:SetColorTexture(0.4, 0.4, 0.4)
        return header
    end

    local function createSlider(name, label, anchor, yOff, min, max, step, settingKey, onChange)
        local s = CreateFrame("Slider", name, content, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
        s:SetMinMaxValues(min, max)
        s:SetValueStep(step)
        s:SetObeyStepOnDrag(true)
        s:EnableMouse(true)
        _G[name .. "Low"]:SetText(tostring(min))
        _G[name .. "High"]:SetText(tostring(max))
        _G[name .. "Text"]:SetText(label)
        local valText = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        valText:SetPoint("TOP", s, "BOTTOM", 0, 0)
        s.valText = valText
        s:SetScript("OnValueChanged", function(self, val)
            if step >= 1 then val = math.floor(val + 0.5) end
            self.valText:SetText(step < 1 and string.format("%.2f", val) or tostring(val))
            if isRefreshing then return end
            ns.Settings:Set(settingKey, val)
            if onChange then onChange(val) end
        end)
        return s
    end

    local function createCheck(name, label, anchor, xOff, yOff, settingKey, onChange)
        local cb = CreateFrame("CheckButton", name, content, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOff, yOff)
        local t = cb.Text or _G[cb:GetName() .. "Text"]
        if t then t:SetText(label) end
        cb:SetScript("OnClick", function(self)
            local v = self:GetChecked() and true or false
            ns.Settings:Set(settingKey, v)
            if onChange then onChange(v) end
        end)
        return cb
    end

    -- ============================================================
    -- Common callbacks
    -- ============================================================
    local function forceRefresh()
        if ns.HUDManager and ns.HUDManager.ForceRefreshSlots then
            ns.HUDManager:ForceRefreshSlots()
        end
    end

    local function hudRebuild()
        if ns.HUDManager then
            ns.HUDManager:DeactivateAll()
            ns.HUDManager:Cleanup()
            ns.HUDManager:Init()
        end
    end

    -- ============================================================
    -- Title + Description
    -- ============================================================
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DHUD Lite")

    local version = GetMeta(ADDON_NAME, "Version") or ""
    local desc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetJustifyH("LEFT")
    desc:SetWidth(700)
    desc:SetText(
        "WoW 12.0 전용 HUD 애드온. 체력/마나 바와 클래스 리소스를 화면 중앙에 표시합니다.\n" ..
        "v" .. version .. "  |  /dhudlite 로 명령어 확인"
    )

    -- ============================================================
    -- Profile section
    -- ============================================================
    local secProfile = createSectionHeader("Profile", desc, -16)

    -- Profile dropdown
    local profDD = CreateFrame("DropdownButton", "DHUDLITE_ProfileDD", content, "WowStyle1DropdownTemplate")
    profDD:SetPoint("TOPLEFT", secProfile, "BOTTOMLEFT", 0, -8)
    profDD:SetWidth(220)
    profDD:SetDefaultText("Select Profile")

    local function ProfileDisplayText(name)
        local count = ns.Settings:GetProfileCharacters(name)
        if count > 0 then
            return name .. " (" .. count .. ")"
        end
        return name
    end

    local function RefreshProfileDropdown()
        profDD:SetupMenu(function(dd, rootDescription)
            local list = ns.Settings:GetProfileList()
            local current = ns.Settings:GetProfileName()
            for _, name in ipairs(list) do
                rootDescription:CreateRadio(
                    ProfileDisplayText(name),
                    function() return ns.Settings:GetProfileName() == name end,
                    function()
                        ns.Settings:SetProfile(name)
                    end,
                    name
                )
            end
        end)
    end

    -- Static popups for profile operations
    StaticPopupDialogs["DHUDLITE_NEW_PROFILE"] = {
        text = "Enter new profile name:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        OnShow = function(self)
            local charName = ns.Settings:GetCharName()
            self.editBox:SetText(charName or "")
            self.editBox:HighlightText()
            -- Create "Copy current settings" checkbox if not already created
            if not self.copyCheck then
                local cb = CreateFrame("CheckButton", nil, self, "UICheckButtonTemplate")
                cb:SetPoint("TOPLEFT", self.editBox, "BOTTOMLEFT", -8, -4)
                local t = cb.Text or _G[cb:GetName() .. "Text"]
                if t then t:SetText("Copy current settings") end
                self.copyCheck = cb
            end
            self.copyCheck:SetChecked(true)
            self.copyCheck:Show()
        end,
        OnAccept = function(self)
            local name = strtrim(self.editBox:GetText())
            if name ~= "" then
                local copyFrom = (self.copyCheck and self.copyCheck:GetChecked()) and ns.Settings:GetProfileName() or nil
                ns.Settings:CreateProfile(name, copyFrom)
                RefreshProfileDropdown()
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local name = strtrim(self:GetText())
            if name ~= "" then
                local copyFrom = (parent.copyCheck and parent.copyCheck:GetChecked()) and ns.Settings:GetProfileName() or nil
                ns.Settings:CreateProfile(name, copyFrom)
                RefreshProfileDropdown()
            end
            parent:Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["DHUDLITE_DELETE_PROFILE"] = {
        text = "Delete profile '%s'?",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function(self, data)
            if ns.Settings:DeleteProfile(data) then
                RefreshProfileDropdown()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["DHUDLITE_RESET_PROFILE"] = {
        text = "Reset profile '%s' to defaults?",
        button1 = "Reset",
        button2 = "Cancel",
        OnAccept = function()
            ns.Settings:ResetProfile()
            RefreshProfileDropdown()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    -- Buttons row
    local btnNew = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnNew:SetSize(80, 22)
    btnNew:SetPoint("LEFT", profDD, "RIGHT", 4, 0)
    btnNew:SetText("New")
    btnNew:SetScript("OnClick", function() StaticPopup_Show("DHUDLITE_NEW_PROFILE") end)

    local btnDelete = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnDelete:SetSize(80, 22)
    btnDelete:SetPoint("LEFT", btnNew, "RIGHT", 4, 0)
    btnDelete:SetText("Delete")
    btnDelete:SetScript("OnClick", function()
        local current = ns.Settings:GetProfileName()
        local dialog = StaticPopup_Show("DHUDLITE_DELETE_PROFILE", current)
        if dialog then dialog.data = current end
    end)

    local btnReset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnReset:SetSize(80, 22)
    btnReset:SetPoint("LEFT", btnDelete, "RIGHT", 4, 0)
    btnReset:SetText("Reset")
    btnReset:SetScript("OnClick", function()
        local current = ns.Settings:GetProfileName()
        StaticPopup_Show("DHUDLITE_RESET_PROFILE", current)
    end)

    -- Use Character Profile button
    local btnCharProfile = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnCharProfile:SetSize(180, 22)
    btnCharProfile:SetPoint("TOPLEFT", profDD, "BOTTOMLEFT", 0, -4)
    btnCharProfile:SetText("Use Character Profile")
    btnCharProfile:SetScript("OnClick", function()
        local charName = ns.Settings:GetCharName()
        if not charName or charName == "" then return end
        -- If profile doesn't exist, create it with current settings copied
        if not ns.Settings:CreateProfile(charName, ns.Settings:GetProfileName()) then
            -- Already exists (CreateProfile printed message) — just switch
        end
        ns.Settings:SetProfile(charName)
        RefreshProfileDropdown()
    end)

    -- Copy From dropdown + button
    local lblCopyFrom = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lblCopyFrom:SetPoint("TOPLEFT", btnCharProfile, "BOTTOMLEFT", 0, -8)
    lblCopyFrom:SetText("Copy From")
    local copyDD = CreateFrame("DropdownButton", "DHUDLITE_CopyFromDD", content, "WowStyle1DropdownTemplate")
    copyDD:SetPoint("TOPLEFT", lblCopyFrom, "BOTTOMLEFT", 0, -2)
    copyDD:SetWidth(220)
    copyDD:SetDefaultText("Copy from...")

    local copySource = nil
    local function RefreshCopyDropdown()
        copySource = nil
        copyDD:SetupMenu(function(dd, rootDescription)
            local list = ns.Settings:GetProfileList()
            local current = ns.Settings:GetProfileName()
            for _, name in ipairs(list) do
                if name ~= current then
                    rootDescription:CreateRadio(
                        name,
                        function() return copySource == name end,
                        function() copySource = name end,
                        name
                    )
                end
            end
        end)
    end

    local btnCopy = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnCopy:SetSize(80, 22)
    btnCopy:SetPoint("LEFT", copyDD, "RIGHT", 4, 0)
    btnCopy:SetText("Copy")
    btnCopy:SetScript("OnClick", function()
        if copySource then
            ns.Settings:CopyProfile(copySource)
            RefreshProfileDropdown()
            RefreshCopyDropdown()
        else
            ns.Print("Select a source profile to copy from.")
        end
    end)


    -- ============================================================
    -- Specialization Profiles section
    -- ============================================================
    local specDropdowns = {}
    local specAnchor = copyDD
    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
    if numSpecs > 0 then
        local secSpec = createSectionHeader("Specialization Profiles", copyDD, -20)
        local prevAnchor = secSpec

        for i = 1, numSpecs do
            local _, specName = GetSpecializationInfo(i)

            local dd = CreateFrame("DropdownButton", "DHUDLITE_SpecDD_" .. i, content, "WowStyle1DropdownTemplate")
            dd:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, i == 1 and -8 or -50)
            dd:SetWidth(220)
            dd:SetDefaultText("(None)")

            local lbl = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            lbl:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 2)
            lbl:SetText(specName or ("Spec " .. i))

            local specIdx = i
            dd:SetupMenu(function(dropdown, rootDescription)
                rootDescription:CreateRadio(
                    "(None)",
                    function() return ns.Settings:GetSpecProfile(specIdx) == nil end,
                    function() ns.Settings:SetSpecProfile(specIdx, nil) end
                )
                local list = ns.Settings:GetProfileList()
                for _, name in ipairs(list) do
                    rootDescription:CreateRadio(
                        name,
                        function() return ns.Settings:GetSpecProfile(specIdx) == name end,
                        function() ns.Settings:SetSpecProfile(specIdx, name) end,
                        name
                    )
                end
            end)

            specDropdowns[i] = dd
            prevAnchor = dd
        end

        specAnchor = prevAnchor
    end

    -- ============================================================
    -- General section
    -- ============================================================
    local secGeneral = createSectionHeader("General", specAnchor, -20)

    local sliderDist = createSlider("DHUDLITE_DistanceSlider", "Bar Distance",
        secGeneral, -28, 0, 150, 5, "barsDistanceDiv2",
        function(val)
            if ns.Layout and ns.Layout.SetBarsDistance then
                ns.Layout:SetBarsDistance(val)
            end
        end)

    local sliderScale = createSlider("DHUDLITE_ScaleSlider", "HUD Scale",
        sliderDist, -55, 0.5, 2.0, 0.05, "scaleMain")

    local cbShortNum = createCheck("DHUDLITE_ShortNumbers", "Short Numbers (K/M)",
        sliderScale, 0, -30, "shortNumbers", forceRefresh)

    local cbHideDead = createCheck("DHUDLITE_HideWhenDead", "Hide When Dead",
        cbShortNum, 0, -6, "hideWhenDead")

    local sliderResScale = createSlider("DHUDLITE_ResourceScaleSlider", "Resource Scale",
        cbHideDead, -28, 0.5, 2.0, 0.05, "scaleResources")

    -- ============================================================
    -- Transparency section
    -- ============================================================
    local secAlpha = createSectionHeader("Transparency", sliderResScale, -20)

    local sliderAlphaCombat = createSlider("DHUDLITE_AlphaInCombat", "In Combat",
        secAlpha, -28, 0, 1.0, 0.05, "alphaInCombat")

    local sliderAlphaTarget = createSlider("DHUDLITE_AlphaHasTarget", "Has Target",
        sliderAlphaCombat, -55, 0, 1.0, 0.05, "alphaHasTarget")

    local sliderAlphaResting = createSlider("DHUDLITE_AlphaResting", "Resting",
        sliderAlphaTarget, -55, 0, 1.0, 0.05, "alphaResting")

    local sliderAlphaIdle = createSlider("DHUDLITE_AlphaIdle", "Idle",
        sliderAlphaResting, -55, 0, 1.0, 0.05, "alphaIdle")

    local sliderFadeSpeed = createSlider("DHUDLITE_FadeSpeedSlider", "Fade Speed",
        sliderAlphaIdle, -55, 1.0, 10.0, 0.5, "alphaFadeSpeed")

    -- ============================================================
    -- Text section
    -- ============================================================
    local secText = createSectionHeader("Text", sliderFadeSpeed, -20)

    -- Text format dropdowns
    local fmtOpts = {
        { v = "value+percent", t = "Value + Percent" },
        { v = "value", t = "Value" },
        { v = "percent", t = "Percent" },
        { v = "deficit", t = "Deficit" },
        { v = "none", t = "None" },
    }
    local function makeFmtDD(key, label, anchor, xOff, yOff)
        local dd = CreateFrame("DropdownButton", "DHUDLITE_TF_" .. key, content, "WowStyle1DropdownTemplate")
        dd:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOff, yOff)
        dd:SetWidth(220)

        local lbl = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lbl:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 2)
        lbl:SetText(label)

        dd:SetupMenu(function(dropdown, rootDescription)
            for _, o in ipairs(fmtOpts) do
                rootDescription:CreateRadio(
                    o.t,
                    function() return ns.Settings:Get(key) == o.v end,
                    function()
                        ns.Settings:Set(key, o.v)
                        forceRefresh()
                    end,
                    o.v
                )
            end
        end)
        return dd
    end

    local tfHealth = makeFmtDD("textFormatHealth", "Health Text", secText, 0, -8)
    local tfPower  = makeFmtDD("textFormatPower",  "Power Text",  tfHealth, 0, -50)

    local sliderFontSize = createSlider("DHUDLITE_FontSizeSlider", "Bar Font Size",
        tfPower, -44, 6, 20, 1, "fontSizeBars")

    -- Font Outline dropdown
    local fontOutlineOpts = {
        { v = 0, t = "None" },
        { v = 1, t = "Outline" },
        { v = 2, t = "Thick Outline" },
    }
    local ddFontOutline = CreateFrame("DropdownButton", "DHUDLITE_FontOutlineDD", content, "WowStyle1DropdownTemplate")
    ddFontOutline:SetPoint("TOPLEFT", sliderFontSize, "BOTTOMLEFT", 0, -52)
    ddFontOutline:SetWidth(220)

    local lblFontOutline = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lblFontOutline:SetPoint("BOTTOMLEFT", ddFontOutline, "TOPLEFT", 0, 2)
    lblFontOutline:SetText("Font Outline")

    ddFontOutline:SetupMenu(function(dd, rootDescription)
        for _, o in ipairs(fontOutlineOpts) do
            rootDescription:CreateRadio(
                o.t,
                function() return ns.Settings:Get("fontOutline") == o.v end,
                function() ns.Settings:Set("fontOutline", o.v) end,
                o.v
            )
        end
    end)

    local sliderInfoFont = createSlider("DHUDLITE_InfoFontSlider", "Info Font Size",
        ddFontOutline, -44, 6, 20, 1, "fontSizeInfo")

    -- ============================================================
    -- Display section
    -- ============================================================
    local secDisplay = createSectionHeader("Display", sliderInfoFont, -20)

    local displayToggles = {}

    -- Row 1: Class Resources
    local cbResources = createCheck("DHUDLITE_ShowResources", "Class Resources",
        secDisplay, 0, -10, "showResources", hudRebuild)
    displayToggles[#displayToggles + 1] = { cb = cbResources, key = "showResources" }

    -- Row 2: PvP Icon, Combat Icon
    local cbPvP = createCheck("DHUDLITE_ShowPvPIcon", "PvP Icon",
        cbResources, 0, -6, "showPvPIcon", forceRefresh)
    displayToggles[#displayToggles + 1] = { cb = cbPvP, key = "showPvPIcon" }

    local cbCombat = createCheck("DHUDLITE_ShowCombatIcon", "Combat Icon",
        cbResources, 200, -6, "showCombatIcon", forceRefresh)
    displayToggles[#displayToggles + 1] = { cb = cbCombat, key = "showCombatIcon" }

    -- Row 3: Elite Dragon, Raid Icon
    local cbElite = createCheck("DHUDLITE_ShowEliteDragon", "Elite Dragon",
        cbPvP, 0, -6, "showEliteDragon", forceRefresh)
    displayToggles[#displayToggles + 1] = { cb = cbElite, key = "showEliteDragon" }

    local cbRaid = createCheck("DHUDLITE_ShowRaidIcon", "Raid Icon",
        cbPvP, 200, -6, "showRaidIcon", forceRefresh)
    displayToggles[#displayToggles + 1] = { cb = cbRaid, key = "showRaidIcon" }

    -- Row 4: Unit Info
    local cbUnitInfo = createCheck("DHUDLITE_ShowUnitInfo", "Unit Info",
        cbElite, 0, -6, "showUnitInfo", hudRebuild)
    displayToggles[#displayToggles + 1] = { cb = cbUnitInfo, key = "showUnitInfo" }

    -- Health Bar Layers sub-header
    local lblHealthLayers = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lblHealthLayers:SetPoint("TOPLEFT", cbUnitInfo, "BOTTOMLEFT", 0, -10)
    lblHealthLayers:SetText("|cffe0c040Health Bar Layers|r")

    -- Row 5: Health Shield, Shield Over Max
    local cbShield = createCheck("DHUDLITE_ShowHealthShield", "Health Shield",
        lblHealthLayers, 0, -6, "showHealthShield", forceRefresh)
    displayToggles[#displayToggles + 1] = { cb = cbShield, key = "showHealthShield" }

    local cbShieldMax = createCheck("DHUDLITE_ShowShieldOverMax", "Shield Over Max",
        lblHealthLayers, 200, -6, "showHealthShieldOverMax", forceRefresh)
    displayToggles[#displayToggles + 1] = { cb = cbShieldMax, key = "showHealthShieldOverMax" }

    -- Row 6: Heal Absorb, Heal Incoming
    local cbHealAbsorb = createCheck("DHUDLITE_ShowHealAbsorb", "Heal Absorb",
        cbShield, 0, -6, "showHealthHealAbsorb", forceRefresh)
    displayToggles[#displayToggles + 1] = { cb = cbHealAbsorb, key = "showHealthHealAbsorb" }

    local cbHealInc = createCheck("DHUDLITE_ShowHealIncoming", "Heal Incoming",
        cbShield, 200, -6, "showHealthHealIncoming", forceRefresh)
    displayToggles[#displayToggles + 1] = { cb = cbHealInc, key = "showHealthHealIncoming" }

    -- Row 7: Health Reduce
    local cbReduce = createCheck("DHUDLITE_ShowHealthReduce", "Health Reduce",
        cbHealAbsorb, 0, -6, "showHealthReduce", forceRefresh)
    displayToggles[#displayToggles + 1] = { cb = cbReduce, key = "showHealthReduce" }

    -- ============================================================
    -- Slots section
    -- ============================================================
    local secSlots = createSectionHeader("Slots", cbReduce, -20)

    local choices = {
        { value = "",             text = "(empty)" },
        { value = "playerHealth", text = "Player Health" },
        { value = "playerPower",  text = "Player Power" },
        { value = "targetHealth", text = "Target Health" },
        { value = "targetPower",  text = "Target Power" },
        { value = "totHealth",    text = "ToT Health" },
        { value = "totPower",     text = "ToT Power" },
        { value = "petHealth",    text = "Pet Health" },
        { value = "petPower",     text = "Pet Power" },
    }

    local textToggles = {} -- slotKey -> CheckButton

    local function makeDropdown(slotKey, labelText, anchorFrame, xOff, yOff)
        local dd = CreateFrame("DropdownButton", "DHUDLITE_DD_" .. slotKey, content, "WowStyle1DropdownTemplate")
        dd:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", xOff, yOff)
        dd:SetWidth(220)
        dd:SetDefaultText("(empty)")

        local lbl = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lbl:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 2)
        lbl:SetText(labelText)

        dd:SetupMenu(function(dropdown, rootDescription)
            for _, c in ipairs(choices) do
                rootDescription:CreateRadio(
                    c.text,
                    function() return (ns.Settings:Get(slotKey) or "") == c.value end,
                    function()
                        ns.Settings:Set(slotKey, c.value)
                        if ns.HUDManager and ns.HUDManager.RebuildSlot then ns.HUDManager:RebuildSlot(slotKey) end
                        if ns.Layout and ns.Layout.RefreshBackgrounds then ns.Layout:RefreshBackgrounds() end
                    end,
                    c.value
                )
            end
        end)

        -- Per-slot text visibility toggle (right next to dropdown)
        local textKey = "showText" .. slotKey:sub(1,1):upper() .. slotKey:sub(2)
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        cb:SetPoint("LEFT", dd, "RIGHT", 4, 0)
        local cbText = cb.Text
        if cbText then cbText:SetText("Show Text") end
        cb:SetChecked(ns.Settings:Get(textKey) and true or false)
        cb:SetScript("OnClick", function(self)
            ns.Settings:Set(textKey, self:GetChecked() and true or false)
            if ns.HUDManager and ns.HUDManager.ForceRefreshSlots then
                ns.HUDManager:ForceRefreshSlots()
            end
        end)
        textToggles[slotKey] = { cb = cb, key = textKey }

        return dd
    end

    -- Single column layout with sub-headers
    local rowHeight = -50

    -- Left Side sub-header
    local lblLeftSide = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lblLeftSide:SetPoint("TOPLEFT", secSlots, "BOTTOMLEFT", 0, -12)
    lblLeftSide:SetText("|cffe0c040Left Side|r")

    local dd1 = makeDropdown("leftBig1",   "L: Inner (Big 1)",   lblLeftSide, 0, -8)
    local dd2 = makeDropdown("leftBig2",   "L: Outer (Big 2)",   dd1,         0, rowHeight)
    local dd3 = makeDropdown("leftSmall1", "L: Inner Small",     dd2,         0, rowHeight)
    local dd4 = makeDropdown("leftSmall2", "L: Outer Small",     dd3,         0, rowHeight)

    -- Right Side sub-header
    local lblRightSide = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lblRightSide:SetPoint("TOPLEFT", dd4, "BOTTOMLEFT", 0, -16)
    lblRightSide:SetText("|cffe0c040Right Side|r")

    local dd5 = makeDropdown("rightBig1",   "R: Inner (Big 1)",   lblRightSide, 0, -8)
    local dd6 = makeDropdown("rightBig2",   "R: Outer (Big 2)",   dd5,          0, rowHeight)
    local dd7 = makeDropdown("rightSmall1", "R: Inner Small",     dd6,          0, rowHeight)
    local dd8 = makeDropdown("rightSmall2", "R: Outer Small",     dd7,          0, rowHeight)

    -- Colors: all hardcoded (Blizzard standard), no UI customization needed

    -- ============================================================
    -- Unified refresh for all controls
    -- ============================================================
    local function refreshAll()
        isRefreshing = true
        -- Profile
        RefreshProfileDropdown()
        RefreshCopyDropdown()
        -- Spec profiles
        for _, dd in pairs(specDropdowns) do
            dd:GenerateMenu()
        end
        -- General
        sliderDist:SetValue(ns.Settings:Get("barsDistanceDiv2") or 0)
        sliderScale:SetValue(ns.Settings:Get("scaleMain") or 1.0)
        cbShortNum:SetChecked(ns.Settings:Get("shortNumbers") and true or false)
        cbHideDead:SetChecked(ns.Settings:Get("hideWhenDead") and true or false)
        sliderResScale:SetValue(ns.Settings:Get("scaleResources") or 1.0)
        -- Transparency
        sliderAlphaCombat:SetValue(ns.Settings:Get("alphaInCombat") or 1.0)
        sliderAlphaTarget:SetValue(ns.Settings:Get("alphaHasTarget") or 0.7)
        sliderAlphaResting:SetValue(ns.Settings:Get("alphaResting") or 0.3)
        sliderAlphaIdle:SetValue(ns.Settings:Get("alphaIdle") or 0.0)
        sliderFadeSpeed:SetValue(ns.Settings:Get("alphaFadeSpeed") or 3.0)
        -- Text
        tfHealth:GenerateMenu()
        tfPower:GenerateMenu()
        sliderFontSize:SetValue(ns.Settings:Get("fontSizeBars") or 10)
        ddFontOutline:GenerateMenu()
        sliderInfoFont:SetValue(ns.Settings:Get("fontSizeInfo") or 10)
        -- Display toggles
        for _, info in ipairs(displayToggles) do
            info.cb:SetChecked(ns.Settings:Get(info.key) and true or false)
        end
        -- Slots
        dd1:GenerateMenu(); dd2:GenerateMenu(); dd3:GenerateMenu(); dd4:GenerateMenu()
        dd5:GenerateMenu(); dd6:GenerateMenu(); dd7:GenerateMenu(); dd8:GenerateMenu()
        for _, info in pairs(textToggles) do
            info.cb:SetChecked(ns.Settings:Get(info.key) and true or false)
        end
        isRefreshing = false
    end

    -- Hook panel show + first-open init + profile change
    panel:HookScript("OnShow", refreshAll)
    refreshAll()

    ns.events:On("PostProfileChanged", profDD, function()
        refreshAll()
    end)
end

-- Register categories (new and legacy) and show helpful messages
local function RegisterCategories()
    local panel = CreateFrame("Frame")
    panel.name = "DHUD Lite"
    panel:Hide()

    -- New settings system (Dragonflight+)
    if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
        settingsCategory = _G.Settings.RegisterCanvasLayoutCategory(panel, "DHUD Lite")
        settingsCategory.ID = "DHUDLITE"
        _G.Settings.RegisterAddOnCategory(settingsCategory)
        if ns and ns.Print then ns.Print("Options: registered Settings category") end
    end

    -- Build controls on demand
    panel:HookScript("OnShow", function()
        BuildControls(panel)
    end)

    if ns and ns.Print then
        ns.Print("Settings registered. Open ESC -> Options -> AddOns (or Interface -> AddOns)")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    RegisterCategories()
end)

-- Public helper to open options programmatically
ns.OpenOptions = function()
    if _G.Settings and _G.Settings.OpenToCategory and settingsCategory then
        _G.Settings.OpenToCategory(settingsCategory.ID)
    else
        if ns and ns.Print then ns.Print("Open Options -> AddOns manually.") end
    end
end
