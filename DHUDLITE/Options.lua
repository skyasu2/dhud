local ADDON_NAME, ns = ...

-- Minimal settings panel so the addon appears in ESC -> Options -> AddOns
local function CreateSettingsPanel()
    local panel = CreateFrame("Frame")
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DHUD Lite")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetJustifyH("LEFT")
    desc:SetWidth(700)
    desc:SetText((
        "한국어 우선, 기술 용어는 영어 병기 가능\n\n" ..
        "슬래시 명령:\n" ..
        "  /dhudlite distance <num>  - 좌우 바 간격(반간격, 픽셀)\n" ..
        "  /dhudlite style <1-5>     - 바 텍스처 스타일\n" ..
        "  /dhudlite castfreq <semi|normal> - 캐스트 업데이트 주기\n" ..
        "  /dhudlite reset           - 설정 초기화 후 리로드\n\n" ..
        "현재 버전: v" .. (GetAddOnMetadata(ADDON_NAME, "Version") or "")
    ))

    -- New settings system (Dragonflight+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "DHUD Lite")
        category.ID = "DHUDLITE"
        Settings.RegisterAddOnCategory(category)
    end

    -- Build simple interactive controls
    local y = -64

    -- Distance slider
    local slider = CreateFrame("Slider", "DHUDLITE_DistanceSlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 16, y)
    slider:SetMinMaxValues(0, 150)
    slider:SetValueStep(5)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
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

    y = y - 60

    -- Background toggle
    local bg = CreateFrame("CheckButton", "DHUDLITE_ShowBackground", panel, "UICheckButtonTemplate")
    bg:SetPoint("TOPLEFT", 16, y)
    local bgText = _G[bg:GetName() .. "Text"] or bg.Text
    if bgText then bgText:SetText("Show Background Mask (empty slots)") end
    bg:SetScript("OnClick", function(self)
        ns.Settings:Set("showBackground", self:GetChecked() and true or false)
        if ns.Layout and ns.Layout.RefreshBackgrounds then ns.Layout:RefreshBackgrounds() end
    end)

    -- Style radios
    local styleLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    styleLabel:SetPoint("TOPLEFT", 16, y - 28)
    styleLabel:SetText("Bar Style")
    local radios = {}
    local prev
    for i = 1, 5 do
        local rb = CreateFrame("CheckButton", "DHUDLITE_Style_" .. i, panel, "UIRadioButtonTemplate")
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
    local cfLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cfLabel:SetPoint("TOPLEFT", 16, y - 64)
    cfLabel:SetText("Cast Update Rate")
    local semi = CreateFrame("CheckButton", "DHUDLITE_CastRate_Semi", panel, "UIRadioButtonTemplate")
    semi:SetPoint("TOPLEFT", cfLabel, "BOTTOMLEFT", 0, -6)
    _G[semi:GetName() .. "Text"]:SetText("semi (~45ms)")
    local normal = CreateFrame("CheckButton", "DHUDLITE_CastRate_Normal", panel, "UIRadioButtonTemplate")
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

    -- Refresh control values when panel shows
    panel:SetScript("OnShow", function()
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
    end)

    -- Slot assignment dropdowns
    local slotLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    slotLabel:SetPoint("TOPLEFT", 16, y - 96)
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

    local function makeDropdown(slotKey, labelText, col, row)
        local dd = CreateFrame("Frame", "DHUDLITE_DD_" .. slotKey, panel, "UIDropDownMenuTemplate")
        local x = 16 + (col - 1) * 260
        local yoff = -140 - (row - 1) * 40
        dd:SetPoint("TOPLEFT",  x, yoff)
        local lbl = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
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
    local dd1 = makeDropdown("leftBig1",   "Left Big 1", 1, 1)
    local dd2 = makeDropdown("leftBig2",   "Left Big 2", 1, 2)
    local dd3 = makeDropdown("leftSmall1", "Left Small 1", 1, 3)
    local dd4 = makeDropdown("leftSmall2", "Left Small 2", 1, 4)
    local dd5 = makeDropdown("rightBig1",   "Right Big 1", 2, 1)
    local dd6 = makeDropdown("rightBig2",   "Right Big 2", 2, 2)
    local dd7 = makeDropdown("rightSmall1", "Right Small 1", 2, 3)
    local dd8 = makeDropdown("rightSmall2", "Right Small 2", 2, 4)

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

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    CreateSettingsPanel()
    -- Legacy options frame fallback (older clients or if Settings UI not available)
    if not (Settings and Settings.RegisterCanvasLayoutCategory) and InterfaceOptions_AddCategory then
        local legacy = CreateFrame("Frame", nil, UIParent)
        legacy.name = "DHUD Lite"
        InterfaceOptions_AddCategory(legacy)
    end
    if ns and ns.Print then
        ns.Print("Settings registered. Open ESC -> Options -> AddOns (or Interface -> AddOns)")
    end
end)
