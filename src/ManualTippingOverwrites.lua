-- removes ability to unload trailer vanilla way
Dischargeable.getCanToggleDischargeToObject = Utils.overwrittenFunction(Dischargeable.getCanToggleDischargeToObject,
    function(self, superFunc, ...)
        local spec = self.spec_manualTipping

        if spec == nil or not spec.isValid then
            return superFunc(self, ...)
        end
        return
    end)

-- disable default unload action events
Dischargeable.onRegisterActionEvents = Utils.overwrittenFunction(Dischargeable.onRegisterActionEvents,
    function(self, superFunc, ...)
        local spec = self.spec_manualTipping

        if spec == nil or not spec.isValid then
            return superFunc(self, ...)
        end
        return
    end)

-- disable lowering trailer when is lifted and player leaves vehicle
Trailer.onDischargeStateChanged = Utils.overwrittenFunction(Trailer.onDischargeStateChanged,
    function(self, superFunc, dischargeState, ...)
        local spec = self.spec_manualTipping

        if spec == nil or not spec.isValid then
            return superFunc(self, dischargeState, ...)
        end

        if dischargeState == Dischargeable.DISCHARGE_STATE_OFF then
            return superFunc(self, dischargeState, ...)
        end

        local rootVehicle = self:getRootVehicle()
        if rootVehicle ~= nil and rootVehicle:getIsAIActive() then
            return superFunc(self, dischargeState, ...)
        end

        if spec.isTipping or spec.isTippingOpen then
            return
        end

        return superFunc(self, dischargeState, ...)
    end)

-- if trailer is lifted or door open block any vanilla behaviour
Trailer.onFillUnitFillLevelChanged = Utils.overwrittenFunction(Trailer.onFillUnitFillLevelChanged,
    function(self, superFunc, ...)
        local spec = self.spec_manualTipping

        if spec == nil or not spec.isValid then
            return superFunc(self, ...)
        end

        local trailerSpec = self.spec_trailer
        local tipSide = trailerSpec ~= nil and trailerSpec.tipSides[trailerSpec.preferedTipSideIndex]
        local doorAnimTime =
            (ManualTipping.hasDoorAnimation(tipSide) and self:getAnimationTime(tipSide.doorAnimation.name) or 0)

        if spec.isTipping or spec.isTippingOpen or doorAnimTime > 0 then
            return
        end

        return superFunc(self, ...)
    end)

-- disable turning engine off when trailer is lifted
Motorized.actionEventToggleMotorState = Utils.overwrittenFunction(Motorized.actionEventToggleMotorState,
    function(self, superFunc, ...)

        local spec = nil
        local root = self:getRootVehicle()

        if root ~= nil then
            for _, implement in pairs(root:getAttachedImplements()) do
                local obj = implement.object
                if obj ~= nil and obj.spec_manualTipping ~= nil then
                    spec = obj.spec_manualTipping
                    break
                end
            end
        end

        if spec == nil or not spec.isValid then
            return superFunc(self, ...)
        end

        if self:getIsMotorStarted() and spec.isTipping then
            g_currentMission:showBlinkingWarning(spec.warningManualEngineTurnOff, 2000)
            return
        end

        return superFunc(self, ...)
    end)

-- block tip side switching when trailer is raised or door is open
Trailer.getCanTogglePreferdTipSide = Utils.overwrittenFunction(Trailer.getCanTogglePreferdTipSide,
    function(self, superFunc)
        local spec = self.spec_manualTipping
        if spec == nil or not spec.isValid then
            return superFunc(self)
        end

        if spec.isTipping or spec.isTippingOpen then
            return false
        end
        return superFunc(self)
    end)

-- prevent detaching trailer while tipping
Attachable.isDetachAllowed = Utils.overwrittenFunction(Attachable.isDetachAllowed, function(self, superFunc, ...)
    if self.spec_manualTipping ~= nil and self.spec_manualTipping.isTipping then
        return false, self.spec_manualTipping.warningDetachRaised, true
    end

    return superFunc(self, ...)
end)
