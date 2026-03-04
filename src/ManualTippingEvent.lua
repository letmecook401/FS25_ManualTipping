ManualTippingEvent = {}
local ManualTippingEvent_mt = Class(ManualTippingEvent, Event)

InitEventClass(ManualTippingEvent, "ManualTippingEvent")

function ManualTippingEvent.emptyNew()
    return Event.new(ManualTippingEvent_mt)
end

function ManualTippingEvent.new(vehicle, state, animTime)
    local self = ManualTippingEvent.emptyNew()
    self.vehicle = vehicle
    self.state = state or 0
    self.animTime = animTime or 0
    return self
end

function ManualTippingEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.state = streamReadInt8(streamId)
    self.animTime = streamReadFloat32(streamId)

    self:run(connection)
end

function ManualTippingEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteInt8(streamId, self.state)
    streamWriteFloat32(streamId, self.animTime)
end

function ManualTippingEvent:run(connection)
    if self.vehicle ~= nil and self.vehicle.spec_manualTipping ~= nil then
        local spec = self.vehicle.spec_manualTipping
        local tipSide = self.vehicle.spec_trailer.tipSides[self.vehicle.spec_trailer.preferedTipSideIndex]

        spec.syncedAnimTime = self.animTime

        if tipSide ~= nil and tipSide.animation ~= nil then
            self.vehicle:setAnimationTime(tipSide.animation.name, self.animTime, true)
        end

        self.vehicle:setTippingState(self.state, true)

    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(ManualTippingEvent.new(self.vehicle, self.state, self.animTime), nil, connection)
    end
end
