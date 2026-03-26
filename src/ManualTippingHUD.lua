local modDirectory = g_currentModDirectory

ManualTippingHUD = {}

ManualTippingHUD.ATLAS = "hud/iconsAtlas.dds"

ManualTippingHUD.UV = {
    TIP_LEFT = {0, 0, 64, 64, 1024, 1024},
    TIP_RIGHT = {64, 0, 64, 64, 1024, 1024},
    TIP_BACK = {128, 0, 64, 64, 1024, 1024},
    TIP_BACKDOOR = {192, 0, 64, 64, 1024, 1024},
    DOOR_OPEN = {0, 64, 64, 64, 1024, 1024},
    DOOR_CLOSED = {64, 64, 64, 64, 1024, 1024},
    TRAILER_LOWERED = {0, 128, 64, 64, 1024, 1024},
    TRAILER_RAISED = {64, 128, 64, 64, 1024, 1024}
}

function ManualTippingHUD.new()
    local self = setmetatable({}, {
        __index = ManualTippingHUD
    })
    self.vehicle = nil
    self.tractorVehicle = nil

    local atlasPath = Utils.getFilename(ManualTippingHUD.ATLAS, modDirectory)

    local function makeIcon(uv)
        local overlay = Overlay.new(atlasPath, 0, 0, 0, 0)
        overlay:setUVs(GuiUtils.getUVs(uv))
        return HUDElement.new(overlay)
    end

    self.icons = {
        tipLeft = makeIcon(ManualTippingHUD.UV.TIP_LEFT),
        tipRight = makeIcon(ManualTippingHUD.UV.TIP_RIGHT),
        tipBack = makeIcon(ManualTippingHUD.UV.TIP_BACK),
        tipBackDoor = makeIcon(ManualTippingHUD.UV.TIP_BACKDOOR),
        doorOpen = makeIcon(ManualTippingHUD.UV.DOOR_OPEN),
        doorClosed = makeIcon(ManualTippingHUD.UV.DOOR_CLOSED),
        trailerLowered = makeIcon(ManualTippingHUD.UV.TRAILER_LOWERED),
        trailerRaised = makeIcon(ManualTippingHUD.UV.TRAILER_RAISED)
    }

    return self
end

function ManualTippingHUD:setVehicle(vehicle)
    self.vehicle = nil
    self.tractorVehicle = nil

    if vehicle == nil then
        return
    end

    self.tractorVehicle = vehicle.rootVehicle or vehicle

    local spec = vehicle.spec_manualTipping
    if spec ~= nil and spec.isValid then
        self.vehicle = vehicle
        return
    end

    if vehicle.getSelectedVehicle ~= nil then
        local selected = vehicle:getSelectedVehicle()
        if selected ~= nil and selected ~= vehicle then
            local selSpec = selected.spec_manualTipping
            if selSpec ~= nil and selSpec.isValid then
                self.vehicle = selected
                return
            end
        end
    end

    if vehicle.getAttachedImplements ~= nil then
        for _, implement in pairs(vehicle:getAttachedImplements()) do
            local obj = implement.object
            if obj ~= nil then
                local implSpec = obj.spec_manualTipping
                if implSpec ~= nil and implSpec.isValid then
                    self.vehicle = obj
                    return
                end
            end
        end
    end
end

function ManualTippingHUD.getTipSideIcon(tipSide, icons)
    local anim = string.lower(tipSide.animation.name or "")

    if string.find(anim, "left") then
        return icons.tipLeft
    elseif string.find(anim, "right") then
        return icons.tipRight
    elseif string.find(anim, "door") or string.find(anim, "grain") or string.find(anim, "hatch") then
        return icons.tipBackDoor
    elseif string.find(anim, "back") or string.find(anim, "rear") then
        return icons.tipBack
    end

    return icons.tipBack
end

function ManualTippingHUD:renderIcon(icon, x, y, w, h)
    icon.overlay:setPosition(x, y)
    icon.overlay:setDimension(w, h)
    icon.overlay:render()
end

function ManualTippingHUD:draw()
    if self.tractorVehicle == nil then
        return
    end

    local root = self.tractorVehicle
    local activeVehicle = nil

    local rootSpec = root.spec_manualTipping
    if rootSpec ~= nil and rootSpec.isValid then
        activeVehicle = root
    end

    if activeVehicle == nil then
        local selected = root:getSelectedVehicle()
        if selected ~= nil and selected ~= root and selected.rootVehicle == root then
            local s = selected.spec_manualTipping
            if s ~= nil and s.isValid then
                activeVehicle = selected
            end
        end
    end

    -- recursive search for first valid trailer
    if activeVehicle == nil then
        local function findValidTrailer(v)
            if v.getAttachedImplements == nil then
                return nil
            end
            for _, impl in pairs(v:getAttachedImplements()) do
                local obj = impl.object
                if obj ~= nil and obj.rootVehicle == root then
                    local s = obj.spec_manualTipping
                    if s ~= nil and s.isValid then
                        return obj
                    end
                    local found = findValidTrailer(obj)
                    if found ~= nil then
                        return found
                    end
                end
            end
            return nil
        end
        activeVehicle = findValidTrailer(root)
    end

    if activeVehicle == nil then
        return
    end

    self.vehicle = activeVehicle

    local spec = self.vehicle.spec_manualTipping
    local trailerSpec = self.vehicle.spec_trailer
    if spec == nil or not spec.isValid or trailerSpec == nil then
        return
    end

    local tipSide = trailerSpec.tipSides[trailerSpec.preferedTipSideIndex]
    if tipSide == nil then
        return
    end

    local uiScale = g_gameSettings:getValue("uiScale")
    local iconWidth = 0.014 * uiScale
    local iconHeight = iconWidth * g_screenAspectRatio
    local padding = 0.004 * uiScale
    local hasDoor = ManualTipping.hasDoorAnimation(tipSide)

    local inputHelp = g_currentMission.hud.inputHelp
    local f1Visible = inputHelp ~= nil and inputHelp.isVisible

    local ihX, ihY = 0.01562, 0.97222
    if inputHelp ~= nil then
        ihX, ihY = inputHelp:getPosition()
    end

    local baseY = ihY - iconHeight

    local baseX
    if f1Visible then
        baseX = ihX + (inputHelp.helpAnchorOffsetX or 0.17708) + padding * 2
    else
        local implementCount = 1
        if root.getAttachedImplements ~= nil then
            local function countImplements(v)
                local count = 0
                for _, impl in pairs(v:getAttachedImplements()) do
                    if impl.object ~= nil then
                        count = count + 1
                        count = count + countImplements(impl.object)
                    end
                end
                return count
            end
            implementCount = 1 + countImplements(root)
        end
        local iconSpacing = (inputHelp.iconSizeX or 0.01354) + (inputHelp.textOffsetX or 0.00729) * 0.2
        baseX = ihX + implementCount * iconSpacing + padding * 4
    end

    local iconCount = hasDoor and 3 or 2
    local bgWidth = iconWidth * iconCount + padding * (iconCount + 1)
    local bgHeight = iconHeight + padding * 2
    local bgY = baseY - padding

    drawFilledRect(baseX, bgY, bgWidth, bgHeight, 0.00439, 0.00478, 0.00368, 0.65)

    local iconY = baseY

    local tipIcon = ManualTippingHUD.getTipSideIcon(tipSide, self.icons)
    self:renderIcon(tipIcon, baseX + padding, iconY, iconWidth, iconHeight)

    if hasDoor then
        local doorIcon = spec.isTippingOpen and self.icons.doorOpen or self.icons.doorClosed
        self:renderIcon(doorIcon, baseX + padding * 2 + iconWidth, iconY, iconWidth, iconHeight)
    end

    local trailerIcon = spec.isTipping and self.icons.trailerRaised or self.icons.trailerLowered
    local trailerX = baseX + padding * (hasDoor and 3 or 2) + iconWidth * (hasDoor and 2 or 1)
    self:renderIcon(trailerIcon, trailerX, iconY, iconWidth, iconHeight)
end

HUD.createDisplayComponents = Utils.appendedFunction(HUD.createDisplayComponents, function(self, uiScale)
    self.manualTippingHUD = ManualTippingHUD.new()
end)

HUD.drawControlledEntityHUD = Utils.appendedFunction(HUD.drawControlledEntityHUD, function(self)
    if self.isVisible and self.manualTippingHUD ~= nil then
        self.manualTippingHUD:draw()
    end
end)

HUD.setControlledVehicle = Utils.appendedFunction(HUD.setControlledVehicle, function(self, vehicle)
    if self.manualTippingHUD ~= nil then
        self.manualTippingHUD:setVehicle(vehicle)
    end
end)
