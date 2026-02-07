local ADDON_NAME, ns = ...

local AlphaManager = {}
ns.AlphaManager = AlphaManager

local TrackerHelper = ns.TrackerHelper
local Settings = ns.Settings
local Layout = ns.Layout

-- States ordered by priority
local STATE_DEAD = 0
local STATE_INCOMBAT = 1
local STATE_HASTARGET = 2
local STATE_RESTING = 3
local STATE_IDLE = 4

local currentState = STATE_IDLE
local currentAlpha = 0
local targetAlpha = 0
local isProcessing = false

local function GetAlphaForState(state)
    if state == STATE_DEAD then
        return Settings:Get("hideWhenDead") and 0 or Settings:Get("alphaIdle")
    elseif state == STATE_INCOMBAT then
        return Settings:Get("alphaInCombat")
    elseif state == STATE_HASTARGET then
        return Settings:Get("alphaHasTarget")
    elseif state == STATE_RESTING then
        return Settings:Get("alphaResting")
    else
        return Settings:Get("alphaIdle")
    end
end

local function DetermineState()
    if TrackerHelper.isDead then
        return STATE_DEAD
    elseif TrackerHelper.isInCombat or TrackerHelper.isAttacking then
        return STATE_INCOMBAT
    elseif TrackerHelper.isTargetAvailable then
        return STATE_HASTARGET
    elseif TrackerHelper.isResting then
        return STATE_RESTING
    else
        return STATE_IDLE
    end
end

local function SetUpdatesRequired(required)
    if isProcessing == required then return end
    isProcessing = required
    if required then
        TrackerHelper.events:On("UpdateFrequent", AlphaManager, AlphaManager.OnUpdate)
    else
        TrackerHelper.events:Off("UpdateFrequent", AlphaManager, AlphaManager.OnUpdate)
    end
end

function AlphaManager:OnUpdate(elapsed)
    elapsed = elapsed or 0.016
    local speed = Settings:Get("alphaFadeSpeed") or 3.0
    local step = speed * elapsed

    if currentAlpha < targetAlpha then
        currentAlpha = currentAlpha + step
        if currentAlpha >= targetAlpha then
            currentAlpha = targetAlpha
        end
    elseif currentAlpha > targetAlpha then
        currentAlpha = currentAlpha - step
        if currentAlpha <= targetAlpha then
            currentAlpha = targetAlpha
        end
    end

    Layout:SetAlpha(currentAlpha)

    -- Show/hide based on alpha
    if currentAlpha <= 0 then
        Layout:SetVisible(false)
        SetUpdatesRequired(false)
    else
        Layout:SetVisible(true)
        if currentAlpha == targetAlpha then
            SetUpdatesRequired(false)
        end
    end
end

function AlphaManager:Refresh()
    local newState = DetermineState()
    currentState = newState
    targetAlpha = GetAlphaForState(currentState)

    if targetAlpha ~= currentAlpha then
        if currentAlpha <= 0 and targetAlpha > 0 then
            Layout:SetVisible(true)
        end
        SetUpdatesRequired(true)
    else
        if currentAlpha <= 0 then
            Layout:SetVisible(false)
        else
            Layout:SetVisible(true)
        end
    end
end

function AlphaManager:ForceAlpha(alpha)
    currentAlpha = alpha
    targetAlpha = alpha
    Layout:SetAlpha(alpha)
    Layout:SetVisible(alpha > 0)
    SetUpdatesRequired(false)
end

function AlphaManager:Init()
    -- Listen to state changes
    TrackerHelper.events:On("CombatChanged", self, self.Refresh)
    TrackerHelper.events:On("AttackChanged", self, self.Refresh)
    TrackerHelper.events:On("TargetChanged", self, self.Refresh)
    TrackerHelper.events:On("DeathChanged", self, self.Refresh)
    TrackerHelper.events:On("RestingChanged", self, self.Refresh)

    -- Set initial state
    currentState = DetermineState()
    currentAlpha = GetAlphaForState(currentState)
    targetAlpha = currentAlpha
    Layout:SetAlpha(currentAlpha)
    Layout:SetVisible(currentAlpha > 0)
end
