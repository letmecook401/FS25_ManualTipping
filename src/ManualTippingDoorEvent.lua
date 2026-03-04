ManualTippingDoorEvent = {}
local ManualTippingDoorEvent_mt = Class(ManualTippingDoorEvent, Event)

InitEventClass(ManualTippingDoorEvent, "ManualTippingDoorEvent")

function ManualTippingDoorEvent.emptyNew()
    return Event.new(ManualTippingDoorEvent_mt)
end

function ManualTippingDoorEvent.new(vehicle, isOpen)
    local self = ManualTippingDoorEvent.emptyNew()
    self.vehicle = vehicle
    self.isOpen = isOpen
    return self
end

function ManualTippingDoorEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.isOpen = streamReadBool(streamId)
    self:run(connection)
end

function ManualTippingDoorEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteBool(streamId, self.isOpen)
end

function ManualTippingDoorEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle.spec_manualTipping ~= nil then
        local spec = self.vehicle.spec_manualTipping
        local tipSide = self.vehicle.spec_trailer.tipSides[self.vehicle.spec_trailer.preferedTipSideIndex]

        spec.isTippingOpen = self.isOpen

        if tipSide ~= nil and tipSide.doorAnimation ~= nil then
            local animTime = self.vehicle:getAnimationTime(tipSide.animation.name)
            local doorTime = self.vehicle:getAnimationTime(tipSide.doorAnimation.name)

            if self.isOpen then
                if animTime > doorTime + 0.001 then
                    spec.doorTargetAnimTime = animTime
                    self.vehicle:playAnimation(tipSide.doorAnimation.name, tipSide.doorAnimation.speedScale, doorTime,
                        true)
                end
            else
                if doorTime > animTime + 0.001 then
                    spec.doorTargetAnimTime = animTime
                    self.vehicle:playAnimation(tipSide.doorAnimation.name, tipSide.doorAnimation.closeSpeedScale,
                        doorTime, true)
                end
            end
        end
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(ManualTippingDoorEvent.new(self.vehicle, self.isOpen), nil, connection)
    end
end
