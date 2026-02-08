local ADDON_NAME, ns = ...

local settingsCategory -- new Settings API category
local legacyPanel -- legacy InterfaceOptions panel
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
    content:SetSize(scrollFrame:GetWidth(), 550) -- Initial approximate height, can be increased
    scrollFrame:SetScrollChild(content)

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DHUD Lite")

    local desc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetJustifyH("LEFT")
    desc:SetWidth(700)
    desc:SetText((
        "한국어 우선, 기술 용어는 영어 병기 가능\n\n" ..
        "주요 명령:\n" ..
        "  /dhudlite options  - 설정 패널 열기\n" ..
        "  /dhudlite move on|off  - 이동 모드 토글\n" ..
        "  /dhudlite visible on|off  - 강제 표시/숨김\n" ..
        "  /dhudlite reset     - 설정 초기화 후 리로드\n\n" ..
        "현재 버전: v" .. (GetMeta(ADDON_NAME, "Version") or "")
    ))

    -- Distance slider
    local slider = CreateFrame("Slider", "DHUDLITE_DistanceSlider", content, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -30) -- Increased spacing slightly
    slider:SetMinMaxValues(0, 150)
    slider:SetValueStep(5)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true) -- Explicitly ensure input
    _G[slider:GetName() .. "Low"]:SetText("0")
    _G[slider:GetName() .. "High"]:SetText("150")
    _G[slider:GetName() .. "Text"]:SetText("Bar Half-Distance")

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val + 0.5)
        ns.Settings:Set("barsDistanceDiv2", val)
        if ns.Layout and ns.Layout.SetBarsDistance then
            ns.Layout:SetBarsDistance(val)
        end
    end)

    -- Background toggle
    local bg = CreateFrame("CheckButton", "DHUDLITE_ShowBackground", content, "UICheckButtonTemplate")
    bg:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -24)
    local bgText = _G[bg:GetName() .. "Text"] or bg.Text
    if bgText then bgText:SetText("Show Background Mask (empty slots)") end
    bg:SetScript("OnClick", function(self)
        ns.Settings:Set("showBackground", self:GetChecked() and true or false)
        if ns.Layout and ns.Layout.RefreshBackgrounds then ns.Layout:RefreshBackgrounds() end
    end)

    -- Style radios
    local styleLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", 0, -16)
    styleLabel:SetText("Bar Style")
    local radios = {}
    local prev
    for i = 1, 5 do
        local rb = CreateFrame("CheckButton", "DHUDLITE_Style_" .. i, content, "UIRadioButtonTemplate")
        if i == 1 then
            rb:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", 0, -6)
        else
            rb:SetPoint("LEFT", prev, "RIGHT", 40, 0)
        end
        _G[rb:GetName() .. "Text"]:SetText(tostring(i))
        rb:SetScript("OnClick", function(self)
            for j = 1, 5 do
                _G["DHUDLITE_Style_" .. j]:SetChecked(j == i)
            end
            ns.Settings:Set("barsTexture", i)
            if ns.Layout and ns.Layout.RefreshBarStyles then ns.Layout:RefreshBarStyles() end
        end)
        radios[i] = rb
        prev = rb
    end

    -- Cast frequency radios
    local cfLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cfLabel:SetPoint("TOPLEFT", styleLabel, "BOTTOMLEFT", 0, -42) -- Spacing after radio buttons line
    cfLabel:SetText("Cast Update Rate")
    local semi = CreateFrame("CheckButton", "DHUDLITE_CastRate_Semi", content, "UIRadioButtonTemplate")
    semi:SetPoint("TOPLEFT", cfLabel, "BOTTOMLEFT", 0, -6)
    _G[semi:GetName() .. "Text"]:SetText("semi (~45ms)")
    local normal = CreateFrame("CheckButton", "DHUDLITE_CastRate_Normal", content, "UIRadioButtonTemplate")
    normal:SetPoint("LEFT", semi, "RIGHT", 120, 0)
    _G[normal:GetName() .. "Text"]:SetText("normal (~95ms)")
    local function setCastRate(val)
        ns.Settings:Set("castUpdateRate", val)
        if val == "semi" then
            semi:SetChecked(true); normal:SetChecked(false)
        else
            semi:SetChecked(false); normal:SetChecked(true)
        end
    end
    semi:SetScript("OnClick", function() setCastRate("semi") end)
    normal:SetScript("OnClick", function() setCastRate("normal") end)

    -- Threat coloring toggle
    local threat = CreateFrame("CheckButton", "DHUDLITE_ThreatColor", content, "UICheckButtonTemplate")
    threat:SetPoint("TOPLEFT", normal, "BOTTOMLEFT", -16, -12)
    local thText = _G[threat:GetName() .. "Text"] or threat.Text
    if thText then thText:SetText("Threat Coloring (Target Health)") end
    threat:SetScript("OnClick", function(self)
        ns.Settings:Set("threatColoring", self:GetChecked() and true or false)
    end)

    -- Text format dropdowns
    local function makeFmtDD(key, label, rel)
        local dd = CreateFrame("Frame", "DHUDLITE_TF_" .. key, content, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", rel, "BOTTOMLEFT", -16, -8)
        local lbl = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lbl:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 16, 0)
        lbl:SetText(label)
        local opts = {
            { v = "value+percent", t = "Value + Percent" },
            { v = "value", t = "Value" },
            { v = "percent", t = "Percent" },
            { v = "deficit", t = "Deficit" },
            { v = "none", t = "None" },
        }
        UIDropDownMenu_SetWidth(dd, 180)
        UIDropDownMenu_Initialize(dd, function()
            for _, o in ipairs(opts) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = o.t
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(dd, o.v)
                    ns.Settings:Set(key, o.v)
                end
                info.value = o.v
                info.checked = (ns.Settings:Get(key) == o.v)
                UIDropDownMenu_AddButton(info)
            end
        end)
        content:HookScript("OnShow", function()
            local cur = ns.Settings:Get(key)
            UIDropDownMenu_SetSelectedValue(dd, cur)
            for _, o in ipairs(opts) do if o.v == cur then UIDropDownMenu_SetText(dd, o.t) end end
        end)
        return dd
    end

    local tfHealth = makeFmtDD("textFormatHealth", "Health Text", threat)
    local tfPower  = makeFmtDD("textFormatPower",  "Power Text",  tfHealth)

    -- Show class resources toggle (merge of multiple flags)
    local res = CreateFrame("CheckButton", "DHUDLITE_ShowResources", content, "UICheckButtonTemplate")
    res:SetPoint("TOPLEFT", tfPower, "BOTTOMLEFT", 16, -18)
    local resText = _G[res:GetName() .. "Text"] or res.Text
    if resText then resText:SetText("Show Class Resources (Combo/Runes/Etc)") end
    res:SetScript("OnClick", function(self)
        ns.Settings:Set("showResources", self:GetChecked() and true or false)
        if ns.HUDManager then
            -- Cleanup listeners then rebuild HUD to apply resource slot on the fly
            ns.HUDManager:DeactivateAll()
            ns.HUDManager:Cleanup()
            ns.HUDManager:Init()
        end
    end)

    -- Refresh control values when panel shows
    panel:HookScript("OnShow", function()
        -- Ensure scrollframe updates
        local dist = ns.Settings:Get("barsDistanceDiv2") or 0
        slider:SetValue(dist)
        bg:SetChecked(ns.Settings:Get("showBackground") and true or false)
        local st = ns.Settings:Get("barsTexture") or 1
        for i = 1, 5 do radios[i]:SetChecked(i == st) end
        local cr = ns.Settings:Get("castUpdateRate") or "semi"
        if cr == "semi" then
            semi:SetChecked(true); normal:SetChecked(false)
        else
            semi:SetChecked(false); normal:SetChecked(true)
        end
        threat:SetChecked(ns.Settings:Get("threatColoring") and true or false)
        res:SetChecked(ns.Settings:Get("showResources") and true or false)
    end)

    -- Slot assignment dropdowns
    local slotLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    slotLabel:SetPoint("TOPLEFT", res, "BOTTOMLEFT", 0, -24)
    slotLabel:SetText("Slots (assign tracker)")

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

    local function makeDropdown(slotKey, labelText, anchorFrame, xOff, yOff)
        local dd = CreateFrame("Frame", "DHUDLITE_DD_" .. slotKey, content, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", xOff, yOff)
        
        local lbl = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        lbl:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 16, 0)
        lbl:SetText(labelText)

        UIDropDownMenu_SetWidth(dd, 180)

        UIDropDownMenu_Initialize(dd, function(self, level)
            for _, c in ipairs(choices) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = c.text
                info.func = function()
                    UIDropDownMenu_SetSelectedValue(dd, c.value)
                    ns.Settings:Set(slotKey, c.value)
                    if ns.HUDManager and ns.HUDManager.RebuildSlot then ns.HUDManager:RebuildSlot(slotKey) end
                    if ns.Layout and ns.Layout.RefreshBackgrounds then ns.Layout:RefreshBackgrounds() end
                end
                info.value = c.value
                info.checked = (ns.Settings:Get(slotKey) or "") == c.value
                UIDropDownMenu_AddButton(info)
            end
        end)

        -- Update selection text
        local cur = ns.Settings:Get(slotKey) or ""
        UIDropDownMenu_SetSelectedValue(dd, cur)
        for _, c in ipairs(choices) do
            if c.value == cur then UIDropDownMenu_SetText(dd, c.text) break end
        end
        return dd
    end

    -- Two columns: left slots and right slots
    -- Column 1
    local col1X = 0
    local col2X = 260
    local rowHeight = -40
    local startY = -20 -- below slotLabel

    local dd1 = makeDropdown("leftBig1",   "Left Big 1",   slotLabel, col1X, startY)
    local dd2 = makeDropdown("leftBig2",   "Left Big 2",   dd1,       0,     rowHeight) -- Relative to dd1
    local dd3 = makeDropdown("leftSmall1", "Left Small 1", dd2,       0,     rowHeight)
    local dd4 = makeDropdown("leftSmall2", "Left Small 2", dd3,       0,     rowHeight)
    
    -- Column 2
    local dd5 = makeDropdown("rightBig1",   "Right Big 1",   slotLabel, col2X, startY)
    local dd6 = makeDropdown("rightBig2",   "Right Big 2",   dd5,       0,     rowHeight) -- Relative to dd5
    local dd7 = makeDropdown("rightSmall1", "Right Small 1", dd6,       0,     rowHeight)
    local dd8 = makeDropdown("rightSmall2", "Right Small 2", dd7,       0,     rowHeight)

    -- Refresh dropdown selections when panel shows
    local function refreshDD(dd, key)
        local val = ns.Settings:Get(key) or ""
        UIDropDownMenu_SetSelectedValue(dd, val)
        for _, c in ipairs(choices) do
            if c.value == val then UIDropDownMenu_SetText(dd, c.text) break end
        end
    end
    panel:HookScript("OnShow", function()
        refreshDD(dd1, "leftBig1")
        refreshDD(dd2, "leftBig2")
        refreshDD(dd3, "leftSmall1")
        refreshDD(dd4, "leftSmall2")
        refreshDD(dd5, "rightBig1")
        refreshDD(dd6, "rightBig2")
        refreshDD(dd7, "rightSmall1")
        refreshDD(dd8, "rightSmall2")
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

    -- Legacy options frame fallback (older clients or if Settings UI not available)
    if _G.InterfaceOptions_AddCategory then
        legacyPanel = CreateFrame("Frame", nil, UIParent)
        legacyPanel.name = "DHUD Lite"
        InterfaceOptions_AddCategory(legacyPanel)
        if ns and ns.Print then ns.Print("Options: registered legacy InterfaceOptions category") end
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
    elseif _G.InterfaceOptionsFrame_OpenToCategory and legacyPanel then
        InterfaceOptionsFrame_OpenToCategory(legacyPanel)
        InterfaceOptionsFrame_OpenToCategory(legacyPanel) -- call twice per Blizzard quirk
    else
        if ns and ns.Print then ns.Print("Open Options -> AddOns manually.") end
    end
end
