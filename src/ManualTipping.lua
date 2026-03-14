ManualTipping = {}
ManualTipping.MOD_NAME = g_currentModName

function ManualTipping.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Trailer, specializations)
end

function ManualTipping.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, "onTippingOpenChanged")
end

function ManualTipping.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "startManualTipping", ManualTipping.startManualTipping)
    SpecializationUtil.registerFunction(vehicleType, "stopManualTipping", ManualTipping.stopManualTipping)
    SpecializationUtil.registerFunction(vehicleType, "reverseTipping", ManualTipping.reverseTipping)
    SpecializationUtil.registerFunction(vehicleType, "stopReverseTipping", ManualTipping.stopReverseTipping)
    SpecializationUtil.registerFunction(vehicleType, "setTippingState", ManualTipping.setTippingState)

end

function ManualTipping.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", ManualTipping)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ManualTipping)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ManualTipping)
    SpecializationUtil.registerEventListener(vehicleType, "updateActionEvents", ManualTipping)

    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ManualTipping)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ManualTipping)
    SpecializationUtil.registerEventListener(vehicleType, "onTippingOpenChanged", ManualTipping)
end

function ManualTipping:onLoad(savegame)
    local spec = self.spec_manualTipping

    spec.isValid = false
    spec.isTipping = false
    spec.isTippingOpen = false

    spec.currentTippingAnimTime = 0
    spec.currentDoorAnimTime = 0
    spec.doorTargetAnimTime = nil
    spec.actionEvents = {}

    spec.startUpText = g_i18n:getText("action_MANUAL_TIPPING_UP", ManualTipping.MOD_NAME)
    spec.startDownText = g_i18n:getText("action_MANUAL_TIPPING_DOWN", ManualTipping.MOD_NAME)
    spec.openTippingText = g_i18n:getText("action_MANUAL_TIPPING_OPEN", ManualTipping.MOD_NAME)
    spec.closeTippingText = g_i18n:getText("action_MANUAL_TIPPING_CLOSE", ManualTipping.MOD_NAME)

    spec.warningPressure = g_i18n:getText("warning_PRESSURE_RAISE", ManualTipping.MOD_NAME)
    spec.warningEngineEnabled = g_i18n:getText("warning_ENGINE_ENABLED", ManualTipping.MOD_NAME)
    spec.warningDetachRaised = g_i18n:getText("warning_DETACH_RAISED", ManualTipping.MOD_NAME)
    spec.warningManualEngineTurnOff = g_i18n:getText("warning_MANUAL_ENGINE_TURN_OFF", ManualTipping.MOD_NAME)

    -- MP states
    spec.tippingState = 0 -- -1 = DOWN, 0 = STOP, 1 = UP

    spec.syncedAnimTime = 0
    spec.syncedDoorTime = 0

    local trailerSpec = self.spec_trailer
    if trailerSpec == nil or trailerSpec.tipSideCount < 1 then
        return
    end

    local tipSide = trailerSpec.tipSides[trailerSpec.preferedTipSideIndex]
    if tipSide == nil or tipSide.animation == nil or tipSide.animation.name == nil then
        return
    end

    if tipSide.manualTipToggle or (tipSide.tippingAnimation ~= nil and tipSide.tippingAnimation.name ~= nil) then
        return
    end

    spec.isValid = true
end

function ManualTipping:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self.spec_manualTipping
    local trailerSpec = self.spec_trailer

    if not spec.isValid or trailerSpec == nil or trailerSpec.tipSideCount < 1 then
        return
    end

    local tipSide = trailerSpec.tipSides[trailerSpec.preferedTipSideIndex]
    if tipSide == nil or tipSide.animation == nil or tipSide.animation.name == nil then
        return
    end

    spec.currentTippingAnimTime = self:getAnimationTime(tipSide.animation.name) or 0
    spec.isTipping = spec.currentTippingAnimTime > 0

    if ManualTipping.hasDoorAnimation(tipSide) then
        spec.currentDoorAnimTime = self:getAnimationTime(tipSide.doorAnimation.name) or 0

        if spec.doorTargetAnimTime ~= nil then
            if spec.currentDoorAnimTime >= spec.doorTargetAnimTime and spec.isTippingOpen then
                self:setAnimationTime(tipSide.doorAnimation.name, spec.doorTargetAnimTime, false)
                self:stopAnimation(tipSide.doorAnimation.name)
                spec.doorTargetAnimTime = nil
            end

            if spec.doorTargetAnimTime ~= nil and spec.doorTargetAnimTime > spec.currentDoorAnimTime and
                not spec.isTippingOpen then
                self:setAnimationTime(tipSide.doorAnimation.name, spec.currentDoorAnimTime, false)
                self:stopAnimation(tipSide.doorAnimation.name)
                spec.doorTargetAnimTime = nil
            end
        elseif spec.isTippingOpen and spec.tippingState == 1 then
            if spec.currentTippingAnimTime > spec.currentDoorAnimTime + 0.001 then
                self:setAnimationTime(tipSide.doorAnimation.name, spec.currentTippingAnimTime, true)
            end
        end
    end

    local tractorVehicle = trailerSpec:getRootVehicle()
    if tractorVehicle ~= nil and tractorVehicle.spec_motorized ~= nil then
        if tractorVehicle:getIsMotorStarted() then
            tractorVehicle.spec_motorized.stopMotorOnLeave = not (spec.isTipping and
                                                                 g_currentMission.missionInfo.automaticMotorStartEnabled)
        end
    end

    -- discharge logic
    local rootVehicle = self:getRootVehicle()
    local isAIActive = rootVehicle ~= nil and rootVehicle:getIsAIActive()

    if not isAIActive then
        local canDischarge = spec.isTipping and (not ManualTipping.hasDoorAnimation(tipSide) or spec.isTippingOpen)

        if canDischarge then
            ManualTipping.startDischarging(spec, self)
        else
            ManualTipping.stopDischarging(spec, self)
        end
    end
end

function ManualTipping:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    local spec = self.spec_manualTipping
    local trailerSpec = self.spec_trailer

    if not self.isClient or not spec.isValid or trailerSpec == nil or trailerSpec.tipSideCount < 1 then
        return
    end

    local tipSide = trailerSpec.tipSides[trailerSpec.preferedTipSideIndex]
    if tipSide == nil or tipSide.animation == nil or tipSide.animation.name == nil then
        return
    end

    if tipSide.manualTipToggle or tipSide.tippingAnimation.name ~= nil then
        return
    end

    if not self:getIsTipSideAvailable(trailerSpec.preferedTipSideIndex) and not spec.isTipping then
        return
    end

    if self.isClient and spec.isValid then
        self:clearActionEventsTable(spec.actionEvents)

        if isActiveForInputIgnoreSelection then
            local _, eventUp = self:addActionEvent(spec.actionEvents, InputAction.MANUAL_TIPPING_UP, self,
                ManualTipping.actionEventBlock, true, true, false, true)

            local _, eventDown = self:addActionEvent(spec.actionEvents, InputAction.MANUAL_TIPPING_DOWN, self,
                ManualTipping.actionEventBlock, true, true, false, true)

            g_inputBinding:setActionEventTextPriority(eventDown, GS_PRIO_NORMAL)
            g_inputBinding:setActionEventTextPriority(eventUp, GS_PRIO_NORMAL)

            if ManualTipping.hasDoorAnimation(tipSide) then
                local _, eventDoor = self:addActionEvent(spec.actionEvents, InputAction.MANUAL_TIPPING_OPEN, self,
                    ManualTipping.actionEventBlock, false, true, false, true, nil)

                g_inputBinding:setActionEventTextPriority(eventDoor, GS_PRIO_NORMAL)
            end
        end
        ManualTipping.updateActionEvents(self)
    end
end

function ManualTipping:updateActionEvents()
    local spec = self.spec_manualTipping

    local eventUp = spec.actionEvents[InputAction.MANUAL_TIPPING_UP]
    local eventDown = spec.actionEvents[InputAction.MANUAL_TIPPING_DOWN]
    local eventDoor = spec.actionEvents[InputAction.MANUAL_TIPPING_OPEN]

    if eventUp ~= nil then
        g_inputBinding:setActionEventText(eventUp.actionEventId, spec.startUpText)
    end

    if eventDoor ~= nil then
        g_inputBinding:setActionEventText(eventDoor.actionEventId,
            spec.isTippingOpen and spec.closeTippingText or spec.openTippingText)
    end

    if eventDown ~= nil then
        local visible = spec.isTipping
        g_inputBinding:setActionEventTextVisibility(eventDown.actionEventId, visible)
        g_inputBinding:setActionEventActive(eventDown.actionEventId, visible)

        if visible then
            g_inputBinding:setActionEventText(eventDown.actionEventId, spec.startDownText)
        end
    end
end

function ManualTipping.actionEventBlock(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_manualTipping
    local trailerSpec = self.spec_trailer
    local tipSide = trailerSpec.tipSides[trailerSpec.preferedTipSideIndex]

    local rootVehicle = self:getRootVehicle()
    local motorized = rootVehicle.spec_motorized

    if motorized == nil or rootVehicle:getMotorState() == MotorState.OFF then
        g_currentMission:showBlinkingWarning(spec.warningEngineEnabled, 2000)
        return
    end

    if rootVehicle:getMotorState() == MotorState.STARTING then
        g_currentMission:showBlinkingWarning(spec.warningPressure, 2000)
        return
    end

    if actionName == InputAction.MANUAL_TIPPING_UP then
        local state = inputValue > 0 and 1 or 0
        self:setTippingState(state)

    elseif actionName == InputAction.MANUAL_TIPPING_DOWN then
        local state = inputValue > 0 and -1 or 0
        self:setTippingState(state)

    elseif actionName == InputAction.MANUAL_TIPPING_OPEN then
        if inputValue > 0 then
            SpecializationUtil.raiseEvent(self, "onTippingOpenChanged")
        end
    end
end

function ManualTipping:onWriteStream(streamId, connection)
    local spec = self.spec_manualTipping

    streamWriteBool(streamId, spec.isTipping)
    streamWriteBool(streamId, spec.isTippingOpen)
    streamWriteInt8(streamId, spec.tippingState)
    streamWriteFloat32(streamId, spec.currentTippingAnimTime)
    streamWriteFloat32(streamId, spec.currentDoorAnimTime)

end

function ManualTipping:onReadStream(streamId, connection)
    local spec = self.spec_manualTipping
    local tipSide = self.spec_trailer.tipSides[self.spec_trailer.preferedTipSideIndex]

    spec.isTipping = streamReadBool(streamId)
    spec.isTippingOpen = streamReadBool(streamId)
    spec.tippingState = streamReadInt8(streamId)
    spec.syncedAnimTime = streamReadFloat32(streamId)
    spec.syncedDoorTime = streamReadFloat32(streamId)

    if tipSide ~= nil and tipSide.animation ~= nil then
        self:setAnimationTime(tipSide.animation.name, spec.syncedAnimTime, true)
    end

    if ManualTipping.hasDoorAnimation(tipSide) then
        self:setAnimationTime(tipSide.doorAnimation.name, spec.syncedDoorTime, true)
    end
end

function ManualTipping:setTippingState(state, noEventSend)
    local spec = self.spec_manualTipping
    local tipSide = self.spec_trailer.tipSides[self.spec_trailer.preferedTipSideIndex]

    if spec.tippingState == state then
        return
    end

    local prevState = spec.tippingState
    spec.tippingState = state
    spec.isTipping = self:getAnimationTime(tipSide.animation.name) > 0

    self:raiseActive()
    self:requestActionEventUpdate()

    if state == 1 then
        self:startManualTipping(spec, tipSide)

    elseif state == -1 then
        self:reverseTipping(spec, tipSide)

    elseif state == 0 then
        if prevState == 1 then
            self:stopManualTipping(spec, tipSide)
        elseif prevState == -1 then
            self:stopReverseTipping(spec, tipSide)
        end
    end

    if not noEventSend then
        local animTime = self:getAnimationTime(tipSide.animation.name)

        if g_server ~= nil then
            g_server:broadcastEvent(ManualTippingEvent.new(self, state, animTime), nil, nil, self)
        else
            g_client:getServerConnection():sendEvent(ManualTippingEvent.new(self, state, animTime))
        end
    end

end

function ManualTipping.hasDoorAnimation(tipSide)
    return tipSide ~= nil and tipSide.doorAnimation ~= nil and tipSide.doorAnimation.name ~= nil
end

function ManualTipping:onTippingOpenChanged(noEventSend)
    local spec = self.spec_manualTipping
    local tipSide = self.spec_trailer.tipSides[self.spec_trailer.preferedTipSideIndex]
    local newState = not spec.isTippingOpen

    spec.isTippingOpen = newState

    if tipSide ~= nil and tipSide.doorAnimation ~= nil then
        local animTime = self:getAnimationTime(tipSide.animation.name)
        local doorTime = self:getAnimationTime(tipSide.doorAnimation.name)

        if animTime > doorTime + 0.001 and spec.isTippingOpen then
            spec.doorTargetAnimTime = animTime

            self:playAnimation(tipSide.doorAnimation.name, tipSide.doorAnimation.speedScale, doorTime, true)
        end

        if doorTime > animTime + 0.001 and not spec.isTippingOpen then
            spec.doorTargetAnimTime = animTime

            self:playAnimation(tipSide.doorAnimation.name, tipSide.doorAnimation.closeSpeedScale, doorTime, true)
        end
    end

    self:raiseActive()
    self:requestActionEventUpdate()

    if not noEventSend then
        if g_server ~= nil then
            g_server:broadcastEvent(ManualTippingDoorEvent.new(self, newState), nil, nil, self)
        else
            g_client:getServerConnection():sendEvent(ManualTippingDoorEvent.new(self, newState))
        end
    end
end

function ManualTipping:startManualTipping(spec, tipSide)
    spec.doorTargetAnimTime = nil

    self:playAnimation(tipSide.animation.name, tipSide.animation.speedScale,
        self:getAnimationTime(tipSide.animation.name), true)
end

function ManualTipping:stopManualTipping(spec, tipSide)
    spec.currentTippingAnimTime = self:getAnimationTime(tipSide.animation.name)
    self:setAnimationTime(tipSide.animation.name, spec.currentTippingAnimTime, false)
    self:stopAnimation(tipSide.animation.name)

    if ManualTipping.hasDoorAnimation(tipSide) and spec.isTippingOpen then
        self:stopAnimation(tipSide.doorAnimation.name)
        spec.currentDoorAnimTime = self:getAnimationTime(tipSide.doorAnimation.name)
    end
end

function ManualTipping:reverseTipping(spec, tipSide)
    spec.doorTargetAnimTime = nil

    self:playAnimation(tipSide.animation.name, tipSide.animation.closeSpeedScale,
        self:getAnimationTime(tipSide.animation.name), true)

    if ManualTipping.hasDoorAnimation(tipSide) then
        if not spec.isTippingOpen and self:getAnimationTime(tipSide.doorAnimation.name) > 0 then
            self:playAnimation(tipSide.doorAnimation.name, tipSide.doorAnimation.closeSpeedScale,
                self:getAnimationTime(tipSide.doorAnimation.name), true)
        end
    end
end

function ManualTipping:stopReverseTipping(spec, tipSide)
    spec.currentTippingAnimTime = self:getAnimationTime(tipSide.animation.name)
    self:setAnimationTime(tipSide.animation.name, spec.currentTippingAnimTime, false)
    self:stopAnimation(tipSide.animation.name)

    if ManualTipping.hasDoorAnimation(tipSide) and not spec.isTippingOpen and
        self:getAnimationTime(tipSide.doorAnimation.name) > 0 then
        self:stopAnimation(tipSide.doorAnimation.name)
        spec.currentDoorAnimTime = self:getAnimationTime(tipSide.doorAnimation.name)
    end
end

function ManualTipping.startDischarging(spec, self)
    local dischargeNodeIndex = self:getCurrentDischargeNodeIndex()
    local dischargeNode = self.spec_dischargeable.dischargeNodes[dischargeNodeIndex]
    local tipSide = self.spec_trailer.tipSides[self.spec_trailer.preferedTipSideIndex]

    if self:getCanDischargeToObject(dischargeNode) then
        if self.spec_dischargeable.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_OBJECT then
            self:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)

            if self.isClient and tipSide.animationNodes ~= nil then
                g_animationManager:startAnimations(tipSide.animationNodes)
            end
        end

    elseif self:getCanDischargeToGround(dischargeNode) and self:getCanDischargeToLand(dischargeNode) and
        self:getCanDischargeAtPosition(dischargeNode) then
        if self.spec_dischargeable.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_GROUND then
            self:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)

            if self.isClient and tipSide.animationNodes ~= nil then
                g_animationManager:startAnimations(tipSide.animationNodes)
            end
        end

    else
        if self.spec_dischargeable.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_OFF then
            self:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)

            if self.isClient and tipSide.animationNodes ~= nil then
                g_animationManager:stopAnimations(tipSide.animationNodes)
            end
        end
    end
end

function ManualTipping.stopDischarging(spec, self)
    local tipSide = self.spec_trailer.tipSides[self.spec_trailer.preferedTipSideIndex]

    if self.spec_dischargeable.currentDischargeState ~= Dischargeable.DISCHARGE_STATE_OFF then
        self:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
        if self.isClient and tipSide ~= nil and tipSide.animationNodes ~= nil then
            g_animationManager:stopAnimations(tipSide.animationNodes)
        end
    end
end
