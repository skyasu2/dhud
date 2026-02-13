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

function BarSlot:UpdateText(valueText, pctText)
    local sn = self.slotName
    local key = "showText" .. sn:sub(1,1):upper() .. sn:sub(2)
    local visible = Settings:Get(key) ~= false
    if self.textField then
        self.textField:DSetText(visible and valueText or "")
    end
    if self.pctField then
        self.pctField:DSetText(visible and pctText or "")
    end
end

function BarSlot:Init(renderer, textFrame, pctTextFrame, unitId)
    self.renderer = renderer
    if textFrame then
        self.textField = textFrame.textField
    end
    if pctTextFrame then
        self.pctField = pctTextFrame.textField
    end
    self.unitId = unitId

    -- Pre-allocate color state and closures to avoid per-frame GC pressure
    local colorState = {}
    self._colorState = colorState

    self._healthColorFunc = function(valueType, hBegin, hEnd)
        if valueType == VT_HEALTH then
            if colorState.noCreditForKill then
                return Colorize:GetHealthLayerColor("notTapped", colorState.unitId)
            end
            local pct = hEnd
            local r, g, b = Colorize:GetHealthColor(pct, colorState.unitId)
            if colorState.unitId == "target" and UnitCanAttack("player", "target") then
                local status = UnitThreatSituation("player", "target") or 0
                if status and status >= 2 then
                    local tr, tg, tb = GetThreatStatusColor(status)
                    if tr then
                        r = (r + tr) * 0.5; g = (g + tg) * 0.5; b = (b + tb) * 0.5
                    end
                end
            end
            return r, g, b
        elseif valueType == VT_ABSORB then
            return Colorize:GetHealthLayerColor("absorb", colorState.unitId)
        elseif valueType == VT_REDUCE then
            return Colorize:GetHealthLayerColor("reduce", colorState.unitId)
        elseif valueType == VT_SHIELD then
            return Colorize:GetHealthLayerColor("shield", colorState.unitId)
        elseif valueType == VT_HEAL then
            return Colorize:GetHealthLayerColor("heal", colorState.unitId)
        end
        return 1, 1, 1
    end

    self._powerColorFunc = function(valueType, hBegin, hEnd)
        if valueType == VT_POWER then
            return Colorize:GetPowerColor(colorState.powerType, colorState.unitId)
        end
        return nil
    end
end

function BarSlot:Activate()
    ns.SlotBase.Activate(self)
    if self.tracker then
        self:BindTracker(self.tracker, {
            DataChanged = self.OnDataChanged,
            ResourceTypeChanged = self.OnDataChanged,
        })
        -- Only start tracking if unit is present; HUDManager will start
        -- tracking later via OnPetChanged / OnTargetChanged when unit appears
        if self.unitId == "player" or UnitExists(self.unitId) then
            self.tracker:StartTracking()
        end
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
    if self.pctField then
        self.pctField:DSetText("")
    end
    ns.SlotBase.Deactivate(self)
end

function BarSlot:OnDataChanged()
    if not self.isActive or not self.tracker then return end
    -- Auto-hide when unit doesn't exist (target/pet/tot)
    if self.unitId ~= "player" and not UnitExists(self.unitId) then
        if self.renderer then self.renderer:HideBar() end
        if self.textField then self.textField:DSetText("") end
        if self.pctField then self.pctField:DSetText("") end
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
        -- Secret Values mode: use StatusBar rendering with curves
        self:UpdateHealthSecret()
        return
    end

    -- Accessible values: full 5-layer rendering with animation
    local amount = t.amount
    local amountMax = t.amountMax
    if amountMax <= 0 then amountMax = 1 end

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

    self._colorState.noCreditForKill = t.noCreditForKill
    self._colorState.unitId = self.unitId

    self.renderer:UpdateBar(self.valuesInfo, self.valuesHeight, sigHeight, self._healthColorFunc)

    -- Calculate text color based on health percentage for consistency
    local cr, cg, cb = 0, 1, 0
    if self._healthColorFunc then
        local pct = 1
        if amountTotalPlusShield > 0 then pct = amount / amountTotalPlusShield end
        cr, cg, cb = self._healthColorFunc(VT_HEALTH, 0, pct)
    end

    -- Update text
    self:UpdateText(TextFormat:FormatHealthValue(t), TextFormat:FormatHealthPct(t))
    if self.textField then self.textField:SetTextColor(cr, cg, cb) end
    if self.pctField then self.pctField:SetTextColor(1, 1, 1) end -- Percent always white
end

-- Secret Values health rendering: StatusBar + C_CurveUtil curves
function BarSlot:UpdateHealthSecret()
    local t = self.tracker
    local r = self.renderer

    -- Get fill value via renderer's fill curve (accounts for texture margins)
    local fillValue
    if r.fillCurve and UnitHealthPercent then
        fillValue = UnitHealthPercent(self.unitId, true, r.fillCurve)
    end

    -- Get health gradient color via color curves
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
    self:UpdateText(TextFormat:FormatHealthValue(t), TextFormat:FormatHealthPct(t))
    if self.textField then self.textField:SetTextColor(cr, cg, cb) end
    if self.pctField then self.pctField:SetTextColor(1, 1, 1) end
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

    self._colorState.powerType = t.resourceType
    self._colorState.unitId = self.unitId

    self.renderer:UpdateBar(self.valuesInfo, self.valuesHeight, 1, self._powerColorFunc)

    -- Calculate power color
    local cr, cg, cb = 1, 1, 1
    if self._powerColorFunc then
        cr, cg, cb = self._powerColorFunc(VT_POWER, 0, 1)
        if not cr then
            cr, cg, cb = Colorize:GetPowerColor(self._colorState.powerType, self._colorState.unitId)
        end
        if not cr then cr, cg, cb = 1, 1, 1 end
    end

    self:UpdateText(TextFormat:FormatPowerValue(t), TextFormat:FormatPowerPct(t))
    if self.textField then self.textField:SetTextColor(cr, cg, cb) end
    if self.pctField then self.pctField:SetTextColor(1, 1, 1) end
end

-- Secret Values power rendering: StatusBar + C_CurveUtil curves
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
    self:UpdateText(TextFormat:FormatPowerValue(t), TextFormat:FormatPowerPct(t))
    if self.textField then self.textField:SetTextColor(cr, cg, cb) end
    if self.pctField then self.pctField:SetTextColor(1, 1, 1) end
end
