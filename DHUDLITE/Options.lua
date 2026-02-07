local ADDON_NAME, ns = ...

-- Minimal settings panel so the addon appears in ESC -> Options -> AddOns
local function CreateSettingsPanel()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then
        return -- Pre-10.0 fallback: no settings panel registration
    end

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

    local category = Settings.RegisterCanvasLayoutCategory(panel, "DHUD Lite")
    category.ID = "DHUDLITE"
    Settings.RegisterAddOnCategory(category)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    CreateSettingsPanel()
end)

