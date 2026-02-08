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

function BarSlot:New(slotName, barType)
    local o = BarSlot.__index.New(self)
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
    if self.barType == "health" then
        self:UpdateHealth()
    else
        self:UpdatePower()
    end
end

function BarSlot:UpdateHealth()
    local t = self.tracker
    local amountMax = t.amountMax
    local amount = t.amount

    -- Secret Values safety: check if values are accessible (IceHUD pattern)
    local canAccess = not canaccessvalue or canaccessvalue(amount)

    -- Percent fallback via UnitHealthPercent API (12.0.0+)
    local healthPct
    if UnitHealthPercent then
        healthPct = (UnitHealthPercent(self.unitId, true) or 0) / 100
    else
        healthPct = (amountMax > 0) and (amount / amountMax) or 0
    end

    local sigHeight

    if canAccess then
        local absorbed = Settings:Get("showHealthHealAbsorb") and t.amountHealAbsorb or 0
        local reduced = Settings:Get("showHealthReduce") and t.amountMaxHealthReduce or 0
        local shield = Settings:Get("showHealthShield") and t.amountExtra or 0
        local heal = Settings:Get("showHealthHealIncoming") and t.amountHealIncoming or 0

        if absorbed > amount then absorbed = amount end
        local amountNonAbsorbed = amount - absorbed

        if heal + amount > amountMax then
            heal = amountMax - amount
            if heal < 0 then heal = 0 end
        end

        local amountTotalPlusShield = amountMax
        local shieldMax = t.amountExtraMax or shield
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

        sigHeight = amountMax / amountTotalPlusShield
    else
        -- Secret Values fallback: use percent API, no extra layers
        self.valuesInfo[1] = VT_HEALTH
        self.valuesHeight[1] = healthPct
        for i = 2, 5 do
            self.valuesInfo[i] = 0
            self.valuesHeight[i] = 0
        end
        sigHeight = 1
    end
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

    -- Update text (Secret Value safe via string.format)
    if self.textField then
        self.textField:DSetText(TextFormat:FormatHealthTextBySetting(t))
    end
end

function BarSlot:UpdatePower()
    local t = self.tracker
    local amountMax = t.amountMax
    local amountMin = t.amountMin
    local amount = t.amount
    local range = amountMax - amountMin

    if range <= 0 then range = 1 end

    -- Secret Values safety
    local canAccess = not canaccessvalue or canaccessvalue(amount)

    if canAccess then
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
    else
        -- Secret Values fallback: approximate percent from amountMax
        local pct = (amountMax > 0) and (amount / amountMax) or 0
        self.valuesInfo[1] = VT_POWER_EMPTY
        self.valuesInfo[2] = VT_POWER
        self.valuesHeight[1] = 0
        self.valuesHeight[2] = pct
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
