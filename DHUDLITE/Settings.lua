local ADDON_NAME, ns = ...

local Settings = {}
ns.Settings = Settings

local defaults = {
    -- Bar texture style (fixed at 2, Classic Bold)
    barsTexture = 2,
    -- Bar distance from center (half-distance, pixels)
    barsDistanceDiv2 = 60,
    -- Alpha settings
    alphaInCombat = 1.0,
    alphaHasTarget = 0.7,
    alphaResting = 0.3,
    alphaIdle = 0.0,
    -- Alpha fade speed
    alphaFadeSpeed = 3.0,
    -- Show bars when dead
    hideWhenDead = true,
    -- Short numbers (K/M)
    shortNumbers = true,
    -- Scale
    scaleMain = 1.0,
    scaleResources = 1.0,
    -- Font sizes
    fontSizeBars = 10,
    fontSizeInfo = 10,
    -- Text outlines (0=none, 1=OUTLINE, 2=THICKOUTLINE)
    fontOutline = 0,
    -- Text formats: "value", "percent", "value+percent", "deficit", "none"
    textFormatHealth = "value+percent",
    textFormatPower = "value+percent",
    -- Per-slot text visibility
    showTextLeftBig1 = true,         -- playerHealth
    showTextLeftBig2 = true,         -- targetHealth
    showTextLeftSmall1 = false,      -- petHealth (no text)
    showTextLeftSmall2 = false,
    showTextRightBig1 = true,        -- playerPower
    showTextRightBig2 = true,        -- targetPower
    showTextRightSmall1 = false,     -- petPower (no text)
    showTextRightSmall2 = false,
    -- Health bar layers
    showHealthShield = true,
    showHealthShieldOverMax = true,
    showHealthHealAbsorb = true,
    showHealthReduce = true,
    showHealthHealIncoming = true,
    -- Colors: all hardcoded in Colorize.lua / UnitInfoTracker.lua (Blizzard standard)
    -- Slot assignments: which data tracker for which slot
    leftBig1 = "playerHealth",
    leftBig2 = "targetHealth",
    leftSmall1 = "petHealth",
    leftSmall2 = "",
    rightBig1 = "playerPower",
    rightBig2 = "targetPower",
    rightSmall1 = "petPower",
    rightSmall2 = "",
    -- Resources (클래스 리소스 표시)
    showResources = true,
    -- Icons
    showPvPIcon = true,
    showCombatIcon = true,
    showEliteDragon = true,
    showRaidIcon = true,
    -- Unit info
    showUnitInfo = true,
}

local db
local rootDb
local activeProfileName
local charKey
local changeCallbacks = {}

-- Apply defaults for missing keys in a profile table
local function _ApplyDefaults(profile)
    -- Migrate legacy resource flags to unified showResources (before defaults)
    if profile.showResources == nil then
        if profile.showComboPoints == false and profile.showDKRunes == false and profile.showClassResources == false then
            profile.showResources = false
        end
    end
    -- Migrate old Small slot defaults (totHealth/totPower → empty)
    if profile.rightSmall1 == "totHealth" then profile.rightSmall1 = "" end
    if profile.rightSmall2 == "totPower" then profile.rightSmall2 = "" end
    -- Force bar texture to Classic Bold (other styles removed)
    if profile.barsTexture ~= 2 then profile.barsTexture = 2 end
    -- Apply defaults for missing keys
    for k, v in pairs(defaults) do
        if profile[k] == nil then
            if type(v) == "table" then
                profile[k] = {}
                for i, sv in ipairs(v) do
                    profile[k][i] = sv
                end
            else
                profile[k] = v
            end
        end
    end
end

-- Strip keys that match defaults (called before SavedVariables serialization)
local function _removeDefaults(profile)
    for k, v in pairs(defaults) do
        if profile[k] == v then
            profile[k] = nil
        end
    end
end

-- Migrate flat V1 DB to V2 profile-based structure
local function _MigrateV1toV2(raw)
    local profile = {}
    local reservedKeys = { _version = true, profiles = true, profileKeys = true }
    for k, v in pairs(raw) do
        if not reservedKeys[k] then
            profile[k] = v
            raw[k] = nil
        end
    end
    raw.profiles = { Default = profile }
    raw.profileKeys = {}
    raw._version = 2
end

function Settings:Init()
    if not DHUDLITE_DB then
        DHUDLITE_DB = {}
    end
    rootDb = DHUDLITE_DB

    -- Migrate V1 (flat) to V2 (profile-based) if needed
    if not rootDb._version then
        _MigrateV1toV2(rootDb)
    end

    -- V2→V3: show all bar text + value+percent format
    if rootDb._version == 2 then
        for _, profile in pairs(rootDb.profiles or {}) do
            if profile.showTextLeftBig1 == false then profile.showTextLeftBig1 = true end
            if profile.showTextRightBig2 == false then profile.showTextRightBig2 = true end
            if profile.textFormatHealth == "percent" then profile.textFormatHealth = "value+percent" end
            if profile.textFormatPower == "percent" then profile.textFormatPower = "value+percent" end
        end
        rootDb._version = 3
    end

    -- V3→V4: hide pet (Small slot) text by default
    if rootDb._version == 3 then
        for _, profile in pairs(rootDb.profiles or {}) do
            profile.showTextLeftSmall1 = false
            profile.showTextLeftSmall2 = false
            profile.showTextRightSmall1 = false
            profile.showTextRightSmall2 = false
        end
        rootDb._version = 4
    end

    -- Ensure structure exists
    if not rootDb.profiles then rootDb.profiles = {} end
    if not rootDb.profileKeys then rootDb.profileKeys = {} end
    if not rootDb.specProfiles then rootDb.specProfiles = {} end
    if not rootDb.profiles["Default"] then rootDb.profiles["Default"] = {} end

    -- Determine character key
    charKey = UnitName("player") .. " - " .. GetRealmName()
    local rawName = UnitName("player")
    local charName = ""
    if rawName and not (issecretvalue and issecretvalue(rawName)) then
        charName = rawName
    end

    -- Auto-create character profile on first login (copy from Default)
    if charName ~= "" and not rootDb.profiles[charName] then
        local src = rootDb.profiles["Default"]
        local new = {}
        for k, v in pairs(src) do
            if type(v) == "table" then
                local t = {}
                for tk, tv in pairs(v) do t[tk] = tv end
                new[k] = t
            else
                new[k] = v
            end
        end
        rootDb.profiles[charName] = new
    end

    -- Auto-bind to character profile on first login
    if not rootDb.profileKeys[charKey] then
        if charName ~= "" and rootDb.profiles[charName] then
            rootDb.profileKeys[charKey] = charName
        end
    end

    activeProfileName = rootDb.profileKeys[charKey] or "Default"

    -- Apply specialization profile override
    local specIndex = GetSpecialization and GetSpecialization() or nil
    if specIndex and rootDb.specProfiles[charKey] then
        local specProfile = rootDb.specProfiles[charKey][specIndex]
        if specProfile and rootDb.profiles[specProfile] then
            activeProfileName = specProfile
            rootDb.profileKeys[charKey] = specProfile
        end
    end

    -- Ensure the assigned profile exists; fall back to Default
    if not rootDb.profiles[activeProfileName] then
        activeProfileName = "Default"
    end
    rootDb.profileKeys[charKey] = activeProfileName

    db = rootDb.profiles[activeProfileName]
    _ApplyDefaults(db)
end

function Settings:Get(key)
    if db then
        local val = db[key]
        if val ~= nil then return val end
    end
    return defaults[key]
end

function Settings:Set(key, value)
    if not db then return end
    db[key] = value
    -- Fire change callbacks
    local cbs = changeCallbacks[key]
    if cbs then
        local n = #cbs
        for i = 1, n do
            local entry = cbs[i]
            if entry then
                entry.fn(entry.obj, key, value)
            end
        end
    end
    ns.events:Fire("SettingChanged", key, value)
end

function Settings:OnChange(key, obj, func)
    local cbs = changeCallbacks[key]
    if not cbs then
        cbs = {}
        changeCallbacks[key] = cbs
    end
    cbs[#cbs + 1] = { obj = obj, fn = func }
end

function Settings:OffChange(key, obj)
    local cbs = changeCallbacks[key]
    if not cbs then return end
    for i = #cbs, 1, -1 do
        if cbs[i].obj == obj then
            table.remove(cbs, i)
        end
    end
end

function Settings:GetDefault(key)
    return defaults[key]
end

function Settings:GetCharKey()
    return charKey
end

function Settings:GetCharName()
    local name = UnitName("player")
    if name and issecretvalue and issecretvalue(name) then
        return ""
    end
    return name or ""
end

function Settings:Reset(key)
    local val = defaults[key]
    if type(val) == "table" then
        local copy = {}
        for k, v in pairs(val) do copy[k] = v end
        self:Set(key, copy)
    else
        self:Set(key, val)
    end
end

-- ============================================================
-- Profile API
-- ============================================================

function Settings:GetProfileName()
    return activeProfileName
end

function Settings:GetProfileList()
    local list = {}
    for name in pairs(rootDb.profiles) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

function Settings:GetProfileCharacters(name)
    local count = 0
    for _, pn in pairs(rootDb.profileKeys) do
        if pn == name then
            count = count + 1
        end
    end
    return count
end

function Settings:SetProfile(name)
    if UnitAffectingCombat("player") then
        ns.Print("Cannot switch profiles during combat.")
        return false
    end
    if not rootDb.profiles[name] then
        ns.Print("Profile '" .. name .. "' does not exist.")
        return false
    end
    if name == activeProfileName then return true end

    ns.events:Fire("PreProfileChanged")

    activeProfileName = name
    rootDb.profileKeys[charKey] = name
    db = rootDb.profiles[name]
    _ApplyDefaults(db)

    ns.events:Fire("PostProfileChanged", name)
    return true
end

function Settings:CreateProfile(name, copyFrom)
    if not name or name == "" then
        ns.Print("Profile name cannot be empty.")
        return false
    end
    if rootDb.profiles[name] then
        ns.Print("Profile '" .. name .. "' already exists.")
        return false
    end
    if copyFrom and rootDb.profiles[copyFrom] then
        -- Deep-copy source profile
        local src = rootDb.profiles[copyFrom]
        local new = {}
        for k, v in pairs(src) do
            if type(v) == "table" then
                local t = {}
                for tk, tv in pairs(v) do t[tk] = tv end
                new[k] = t
            else
                new[k] = v
            end
        end
        rootDb.profiles[name] = new
    else
        rootDb.profiles[name] = {}
        _ApplyDefaults(rootDb.profiles[name])
    end
    ns.Print("Profile '" .. name .. "' created.")
    return true
end

function Settings:DeleteProfile(name)
    if not name or not rootDb.profiles[name] then
        ns.Print("Profile '" .. tostring(name) .. "' does not exist.")
        return false
    end
    if name == activeProfileName then
        ns.Print("Cannot delete the active profile. Switch first.")
        return false
    end
    if name == "Default" then
        ns.Print("Cannot delete the Default profile.")
        return false
    end
    rootDb.profiles[name] = nil
    -- Reassign any characters using the deleted profile to Default
    for ck, pn in pairs(rootDb.profileKeys) do
        if pn == name then
            rootDb.profileKeys[ck] = "Default"
        end
    end
    -- Clean up specProfiles references
    if rootDb.specProfiles then
        for _, mapping in pairs(rootDb.specProfiles) do
            for specIdx, pn in pairs(mapping) do
                if pn == name then mapping[specIdx] = nil end
            end
        end
    end
    ns.Print("Profile '" .. name .. "' deleted.")
    return true
end

function Settings:CopyProfile(srcName)
    if UnitAffectingCombat("player") then
        ns.Print("Cannot copy profiles during combat.")
        return false
    end
    if not srcName or not rootDb.profiles[srcName] then
        ns.Print("Source profile '" .. tostring(srcName) .. "' does not exist.")
        return false
    end
    if srcName == activeProfileName then
        ns.Print("Source and current profile are the same.")
        return false
    end

    ns.events:Fire("PreProfileChanged")

    -- Overwrite current profile with source data
    local src = rootDb.profiles[srcName]
    local cur = rootDb.profiles[activeProfileName]
    -- Wipe current
    for k in pairs(cur) do cur[k] = nil end
    -- Copy
    for k, v in pairs(src) do
        if type(v) == "table" then
            local t = {}
            for tk, tv in pairs(v) do t[tk] = tv end
            cur[k] = t
        else
            cur[k] = v
        end
    end
    db = cur
    _ApplyDefaults(db)

    ns.events:Fire("PostProfileChanged", activeProfileName)
    ns.Print("Copied profile '" .. srcName .. "' to '" .. activeProfileName .. "'.")
    return true
end

function Settings:ResetProfile()
    if UnitAffectingCombat("player") then
        ns.Print("Cannot reset profile during combat.")
        return false
    end

    ns.events:Fire("PreProfileChanged")

    -- Wipe current profile and reapply defaults
    local cur = rootDb.profiles[activeProfileName]
    for k in pairs(cur) do cur[k] = nil end
    _ApplyDefaults(cur)
    db = cur

    ns.events:Fire("PostProfileChanged", activeProfileName)
    ns.Print("Profile '" .. activeProfileName .. "' reset to defaults.")
    return true
end

-- ============================================================
-- Specialization Profile API
-- ============================================================

function Settings:GetSpecProfile(specIndex)
    if not rootDb.specProfiles or not rootDb.specProfiles[charKey] then
        return nil
    end
    return rootDb.specProfiles[charKey][specIndex]
end

function Settings:SetSpecProfile(specIndex, profileName)
    if not rootDb.specProfiles then rootDb.specProfiles = {} end
    if not rootDb.specProfiles[charKey] then rootDb.specProfiles[charKey] = {} end
    if profileName == "" or profileName == nil then
        rootDb.specProfiles[charKey][specIndex] = nil
    else
        rootDb.specProfiles[charKey][specIndex] = profileName
    end
end

function Settings:OnSpecChanged()
    if UnitAffectingCombat("player") then return end
    local specIndex = GetSpecialization and GetSpecialization() or nil
    if not specIndex then return end
    if not rootDb.specProfiles or not rootDb.specProfiles[charKey] then return end
    local specProfile = rootDb.specProfiles[charKey][specIndex]
    if not specProfile or not rootDb.profiles[specProfile] then return end
    if specProfile == activeProfileName then return end
    self:SetProfile(specProfile)
end

function Settings:PrepareForSave()
    if not rootDb or not rootDb.profiles then return end
    for _, profile in pairs(rootDb.profiles) do
        _removeDefaults(profile)
    end
end
