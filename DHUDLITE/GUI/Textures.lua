local ADDON_NAME, ns = ...

local Textures = {}
ns.Textures = Textures

local ART = "Interface\\AddOns\\DHUDLITE\\art\\"

-- Texture registry: name -> { path, x0, x1, y0, y1 }
Textures.list = {
    -- Backgrounds
    BackgroundBars0B0S     = { ART .. "bg_0",    0, 1, 0, 1 },
    BackgroundBars1BI0S    = { ART .. "bg_1",    0, 1, 0, 1 },
    BackgroundBars1BI1SI   = { ART .. "bg_1p",   0, 1, 0, 1 },
    BackgroundBars1BO0S    = { ART .. "bg_2",    0, 1, 0, 1 },
    BackgroundBars2B0S     = { ART .. "bg_21",   0, 1, 0, 1 },
    BackgroundBars2B1SI    = { ART .. "bg_21p",  0, 1, 0, 1 },
    BackgroundBars2B2S     = { ART .. "bg_21pp", 0, 1, 0, 1 },
    -- Bar texture prefixes (append style number 1-5)
    TexturePrefixBarB1     = { ART .. "1",  0, 1, 0, 1 },
    TexturePrefixBarB2     = { ART .. "2",  0, 1, 0, 1 },
    TexturePrefixBarS1     = { ART .. "p1", 0, 1, 0, 1 },
    TexturePrefixBarS2     = { ART .. "p2", 0, 1, 0, 1 },
    -- Cast bars
    CastingBarB1   = { ART .. "cb",   0, 1, 0, 1 },
    CastFlashBarB1 = { ART .. "cbh",  0, 1, 0, 1 },
    CastFillBarB1  = { ART .. "cbe",  0, 1, 0, 1 },
    CastingBarB2   = { ART .. "ecb",  0, 1, 0, 1 },
    CastFlashBarB2 = { ART .. "ecbh", 0, 1, 0, 1 },
    CastFillBarB2  = { ART .. "ecbe", 0, 1, 0, 1 },
    -- Combo circles
    ComboCircleRed       = { ART .. "c1", 0, 1, 0, 1 },
    ComboCircleJadeGreen = { ART .. "c2", 0, 1, 0, 1 },
    ComboCircleCyan      = { ART .. "c3", 0, 1, 0, 1 },
    ComboCircleOrange    = { ART .. "c4", 0, 1, 0, 1 },
    ComboCircleGreen     = { ART .. "c5", 0, 1, 0, 1 },
    ComboCirclePurple    = { ART .. "c6", 0, 1, 0, 1 },
    -- Special
    TargetEliteDragon  = { ART .. "elite", 0, 1, 0, 1 },
    TargetRareDragon   = { ART .. "rare",  0, 1, 0, 1 },
    OverlaySpellCircle = { ART .. "serenity0", 0, 1, 0, 1 },
    -- Blizzard textures
    BlizzardCastBarIconShield  = { "Interface\\CastingBar\\UI-CastingBar-Arena-Shield", 0.015625, 0.609375, 0.1875, 0.875 },
    BlizzardPvPHorde           = { "Interface\\TargetingFrame\\UI-PVP-Horde", 0.6, 0, 0, 0.6 },
    BlizzardPvPAlliance        = { "Interface\\TargetingFrame\\UI-PVP-Alliance", 0, 0.6, 0, 0.6 },
    BlizzardPvPArena           = { "Interface\\TargetingFrame\\UI-PVP-FFA", 0, 0.6, 0, 0.6 },
    BlizzardPlayerResting      = { "Interface\\CharacterFrame\\UI-StateIcon", 0.0625, 0.4475, 0.0625, 0.4375 },
    BlizzardPlayerInCombat     = { "Interface\\CharacterFrame\\UI-StateIcon", 0.5625, 0.9375, 0.0625, 0.4375 },
    BlizzardPlayerLeader       = { "Interface\\GroupFrame\\UI-Group-LeaderIcon", 0, 1, 0, 1 },
    BlizzardDKRuneBlood   = { "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood", 0, 1, 0, 1 },
    BlizzardDKRuneFrost   = { "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost", 0, 1, 0, 1 },
    BlizzardDKRuneUnholy  = { "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy", 0, 1, 0, 1 },
    BlizzardDKRuneDeath   = { "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-SingleRune", 0, 1, 0, 1 },
}

-- Raid icons (1-8)
for i = 1, 8 do
    local col = ((i - 1) % 4) * 0.25
    local row = math.floor((i - 1) / 4) * 0.25
    Textures.list["BlizzardRaidIcon" .. i] = {
        "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
        col, col + 0.25, row, row + 0.25
    }
end

-- Clipping info: { pixelsHeight, pixelsFromTop, pixelsFromBottom }
Textures.clipping = {
    TexturePrefixBarB1 = { 256, 11, 11 },
    TexturePrefixBarB2 = { 256,  5,  5 },
    TexturePrefixBarS1 = { 256, 128, 20 },
    TexturePrefixBarS2 = { 256, 128, 20 },
    CastingBarB1       = { 256, 11, 11 },
    CastFlashBarB1     = { 256, 11, 11 },
    CastFillBarB1      = { 256, 11, 11 },
    CastingBarB2       = { 256,  5,  5 },
    CastFlashBarB2     = { 256,  5,  5 },
    CastFillBarB2      = { 256,  5,  5 },
}

-- Fonts
Textures.fonts = {
    default = GetLocale() == "ruRU" and "Fonts\\FRIZQT___CYR.TTF" or "Fonts\\FRIZQT__.TTF",
    numeric = ART .. "Number.TTF",
}

-- Font outlines
Textures.FONT_OUTLINES = { "", "OUTLINE", "THICKOUTLINE" }

function Textures:GetPath(name)
    local info = self.list[name]
    return info and info[1] or nil
end

function Textures:GetCoords(name)
    local info = self.list[name]
    if info then
        return info[2], info[3], info[4], info[5]
    end
    return 0, 1, 0, 1
end

function Textures:GetClipping(name)
    return self.clipping[name]
end
