local ADDON_NAME, ns = ...

local BarSlot = ns.CreateClass(ns.SlotBase, {})
ns.BarSlot = BarSlot

local Colorize = ns.Colorize
local TextFormat = ns.TextFormat
local Settings = ns.Settings

-- Value types for health bar layers
local VT_HEALTH = 1
local VT_ABSORB = 2
local VT_REDUCE = 3
local VT_SHIELD = 4
local VT_HEAL = 5
local VT_POWER = 1
local VT_POWER_EMPTY = 0

-- Safe number extraction: returns default if val is nil or a secret value
local function _safe(val, default)
    if val == nil then return default or 0 end
    if canaccessvalue and not canaccessvalue(val) then return default or 0 end
    return val
end

function BarSlot:New(slotName, barType)
    local o = BarSlot.super.New(self)
    o.slotName = slotName
    o.barType = barType -- "health" or "power"
    o.renderer = nil
    o.textField = nil
    o.unitId = "player"
    o.valuesInfo = {}
    o.valuesHeight = {}
    return o
end

function BarSlot:Init(renderer, textFrame, unitId)
    self.renderer = renderer
    if textFrame then
        self.textField = textFrame.textField
    end
    self.unitId = unitId
end

function BarSlot:Activate()
    ns.SlotBase.Activate(self)
    if self.tracker then
        self:BindTracker(self.tracker, {
            DataChanged = self.OnDataChanged,
            ResourceTypeChanged = self.OnDataChanged,
        })
        self.tracker:StartTracking()
        self:OnDataChanged()
    end
end

function BarSlot:Deactivate()
    if self.tracker then
        self.tracker:StopTracking()
    end
    if self.renderer then
        self.renderer:HideBar()
    end
    if self.textField then
        self.textField:DSetText("")
    end
    ns.SlotBase.Deactivate(self)
end

function BarSlot:OnDataChanged()
    if not self.isActive or not self.tracker then return end
    -- Auto-hide when unit doesn't exist (target/pet/tot)
    if self.unitId ~= "player" and not UnitExists(self.unitId) then
        if self.renderer then self.renderer:HideBar() end
        if self.textField then self.textField:DSetText("") end
        return
    end
    if self.barType == "health" then
        self:UpdateHealth()
    else
        self:UpdatePower()
    end
end

function BarSlot:UpdateHealth()
    local t = self.tracker
    local _cav = canaccessvalue

    -- Secret Values safety: check actual tracker values before arithmetic
    local canAccess = not _cav or (_cav(t.amount) and _cav(t.amountMax))

    if not canAccess then
        -- Secret Values mode: use StatusBar rendering with curves (IceHUD pattern)
        self:UpdateHealthSecret()
        return
    end

    -- Accessible values: full 5-layer rendering with animation
    local amount = t.amount
    local amountMax = t.amountMax
    if amountMax <= 0 then amountMax = 1 end
    local healthPct = amount / amountMax

    local absorbed = Settings:Get("showHealthHealAbsorb") and _safe(t.amountHealAbsorb) or 0
    local reduced = Settings:Get("showHealthReduce") and _safe(t.amountMaxHealthReduce) or 0
    local shield = Settings:Get("showHealthShield") and _safe(t.amountExtra) or 0
    local heal = Settings:Get("showHealthHealIncoming") and _safe(t.amountHealIncoming) or 0

    if absorbed > amount then absorbed = amount end
    local amountNonAbsorbed = amount - absorbed

    if heal + amount > amountMax then
        heal = amountMax - amount
        if heal < 0 then heal = 0 end
    end

    local amountTotalPlusShield = amountMax
    local shieldMax = _safe(t.amountExtraMax, shield)
    if amount + shieldMax > amountMax then
        amountTotalPlusShield = amount + shieldMax
        if not Settings:Get("showHealthShieldOverMax") then
            if amount <= amountMax * 0.95 then
                amountTotalPlusShield = amountMax
            else
                amountTotalPlusShield = math.min(amountTotalPlusShield, amount + amountMax * 0.05)
            end
        end
    end

    if shield + amount > amountTotalPlusShield then
        shield = amountTotalPlusShield - amount
        if shield < 0 then shield = 0 end
    end

    if amountTotalPlusShield <= 0 then amountTotalPlusShield = 1 end

    self.valuesInfo[1] = VT_HEALTH
    self.valuesInfo[2] = VT_ABSORB
    self.valuesInfo[3] = VT_REDUCE
    self.valuesInfo[4] = VT_SHIELD
    self.valuesInfo[5] = VT_HEAL
    self.valuesHeight[1] = amountNonAbsorbed / amountTotalPlusShield
    self.valuesHeight[2] = absorbed / amountTotalPlusShield
    self.valuesHeight[3] = reduced / amountTotalPlusShield
    self.valuesHeight[4] = shield / amountTotalPlusShield
    self.valuesHeight[5] = heal / amountTotalPlusShield

    local sigHeight = amountMax / amountTotalPlusShield
    local unitId = self.unitId
    local noCreditForKill = t.noCreditForKill

    self.renderer:UpdateBar(self.valuesInfo, self.valuesHeight, sigHeight, function(valueType, hBegin, hEnd)
        if valueType == VT_HEALTH then
            if noCreditForKill then
                return Colorize:GetHealthLayerColor("notTapped", unitId)
            end
            local pct = hEnd
            local r, g, b = Colorize:GetHealthColor(pct, unitId)
            -- Threat coloring overlay for target health (IceHUD-like)
            if ns.Settings:Get("threatColoring") and unitId == "target" and UnitCanAttack("player", "target") then
                local status = UnitThreatSituation("player", "target") or 0
                if status and status >= 2 then -- 2=high, 3=aggro
                    local tr, tg, tb = GetThreatStatusColor(status)
                    -- Blend threat color with base
                    r = (r + tr) * 0.5; g = (g + tg) * 0.5; b = (b + tb) * 0.5
                end
            end
            return r, g, b
        elseif valueType == VT_ABSORB then
            return Colorize:GetHealthLayerColor("absorb", unitId)
        elseif valueType == VT_REDUCE then
            return Colorize:GetHealthLayerColor("reduce", unitId)
        elseif valueType == VT_SHIELD then
            return Colorize:GetHealthLayerColor("shield", unitId)
        elseif valueType == VT_HEAL then
            return Colorize:GetHealthLayerColor("heal", unitId)
        end
        return 1, 1, 1
    end)

    -- Update text
    if self.textField then
        self.textField:DSetText(TextFormat:FormatHealthTextBySetting(t))
    end
end

-- Secret Values health rendering: StatusBar + C_CurveUtil curves (IceHUD pattern)
function BarSlot:UpdateHealthSecret()
    local t = self.tracker
    local r = self.renderer

    -- Get fill value via renderer's fill curve (accounts for texture margins)
    local fillValue
    if r.fillCurve and UnitHealthPercent then
        fillValue = UnitHealthPercent(self.unitId, true, r.fillCurve)
    end

    -- Get health gradient color via color curves (IceHUD pattern)
    local cr, cg, cb = 0, 1, 0 -- default green
    if r.hpColorCurveR and UnitHealthPercent then
        cr = UnitHealthPercent(self.unitId, true, r.hpColorCurveR) or 0
        cg = UnitHealthPercent(self.unitId, true, r.hpColorCurveG) or 0
        cb = 0
    end

    -- Tapped (no credit) coloring
    if t.noCreditForKill then
        cr, cg, cb = Colorize:GetHealthLayerColor("notTapped", self.unitId)
    end

    r:UpdateBarSecret(fillValue, cr, cg, cb)

    -- Update text
    if self.textField then
        self.textField:DSetText(TextFormat:FormatHealthTextBySetting(t))
    end
end

function BarSlot:UpdatePower()
    local t = self.tracker
    local _cav = canaccessvalue
    local canAccess = not _cav or (_cav(t.amount) and _cav(t.amountMax))

    if not canAccess then
        -- Secret Values mode: use StatusBar rendering
        self:UpdatePowerSecret()
        return
    end

    -- Accessible values: standard rendering
    local amountMax = t.amountMax
    local amountMin = t.amountMin
    local amount = t.amount
    local range = amountMax - amountMin
    if range <= 0 then range = 1 end

    if amountMin == 0 then
        self.valuesInfo[1] = VT_POWER_EMPTY
        self.valuesInfo[2] = VT_POWER
        self.valuesHeight[1] = 0
        self.valuesHeight[2] = amount / range
    else
        if amount >= 0 then
            self.valuesInfo[1] = VT_POWER_EMPTY
            self.valuesInfo[2] = VT_POWER
            self.valuesHeight[1] = -amountMin / range
            self.valuesHeight[2] = amount / range
        else
            self.valuesInfo[1] = VT_POWER
            self.valuesInfo[2] = VT_POWER_EMPTY
            self.valuesHeight[1] = (amount - amountMin) / range
            self.valuesHeight[2] = -amount / range
        end
    end

    -- Trim arrays to 2
    while #self.valuesInfo > 2 do table.remove(self.valuesInfo) end
    while #self.valuesHeight > 2 do table.remove(self.valuesHeight) end

    local unitId = self.unitId
    local powerType = t.resourceType

    self.renderer:UpdateBar(self.valuesInfo, self.valuesHeight, 1, function(valueType, hBegin, hEnd)
        if valueType == VT_POWER then
            return Colorize:GetPowerColor(powerType, unitId)
        end
        return nil  -- invisible for empty segment
    end)

    if self.textField then
        self.textField:DSetText(TextFormat:FormatPowerTextBySetting(t))
    end
end

-- Secret Values power rendering: StatusBar + C_CurveUtil curves (IceHUD pattern)
function BarSlot:UpdatePowerSecret()
    local t = self.tracker
    local r = self.renderer

    -- Get fill value via renderer's fill curve
    local fillValue
    if r.fillCurve and UnitPowerPercent then
        fillValue = UnitPowerPercent(self.unitId, t.resourceType, true, r.fillCurve)
    end

    -- Power color doesn't depend on fill level, safe to use directly
    local cr, cg, cb = Colorize:GetPowerColor(t.resourceType, self.unitId)

    r:UpdateBarSecret(fillValue, cr, cg, cb)

    -- Update text
    if self.textField then
        self.textField:DSetText(TextFormat:FormatPowerTextBySetting(t))
    end
end
