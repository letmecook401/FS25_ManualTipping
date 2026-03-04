--[[
RegisterSpecialization

Author:		Ifko[nator]
Date:		21.04.2022
Version:	2.6
]] RegisterSpecialization = {};
RegisterSpecialization.currentModDirectory = g_currentModDirectory;

local allowedVehicleTypes = {"loaderVehicle", "trailer", "hookLiftContainerTrailer", "stonePicker", "tippingAugerWagon",
                             "forageWagon", "baseTipper", "trailerLiftableAxle"}

function RegisterSpecialization:addSpecializations()
    local modDesc = loadXMLFile("modDesc", RegisterSpecialization.currentModDirectory .. "modDesc.xml");

    RegisterSpecialization.debugPriority = Utils.getNoNil(getXMLInt(modDesc,
        "modDesc.registerSpecializations#debugPriority"), 0);
        
    local specializationNumber = 0;

    while true do
        local specializationKey = string.format("modDesc.registerSpecializations.registerSpecialization(%d)",
            specializationNumber);

        if not hasXMLProperty(modDesc, specializationKey) then
            break
        end

        local specializationName = Utils.getNoNil(getXMLString(modDesc, specializationKey .. "#name"), "");

        local specializationClassName = Utils.getNoNil(getXMLString(modDesc, specializationKey .. "#className"), "");
        local specializationFilename = Utils.getNoNil(Utils.getFilename(getXMLString(modDesc,
            specializationKey .. "#filename"), RegisterSpecialization.currentModDirectory), "");

        local searchedSpecializations = string.split(Utils.getNoNil(
            getXMLString(modDesc, specializationKey .. "#searchedSpecializations"), ""), " ");

        if specializationName ~= "" and specializationClassName ~= "" and specializationFilename ~= "" and
            fileExists(specializationFilename) and searchedSpecializations ~= "" then
            if g_specializationManager:getSpecializationByName(specializationName) == nil then
                g_specializationManager:addSpecialization(specializationName, specializationClassName,
                    specializationFilename, nil);
            end

            for vehicleType, vehicle in pairs(g_vehicleTypeManager.types) do
                if vehicle ~= nil then
                    for name in pairs(vehicle.specializationsByName) do
                        for _, searchedSpecialization in pairs(searchedSpecializations) do
                            if string.lower(name) == string.lower(searchedSpecialization) then
                                local specializationObject =
                                    g_specializationManager:getSpecializationObjectByName(specializationName);

                                for _, allowedType in ipairs(allowedVehicleTypes) do
                                    if vehicleType == allowedType then
                                        if vehicle.specializationsByName[specializationName] == nil then
                                            vehicle.specializationsByName[specializationName] = specializationObject;
                                            table.insert(vehicle.specializationNames, specializationName);
                                            table.insert(vehicle.specializations, specializationObject);
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        specializationNumber = specializationNumber + 1;
    end

    delete(modDesc)
end

TypeManager.finalizeTypes =
    Utils.prependedFunction(TypeManager.finalizeTypes, RegisterSpecialization.addSpecializations)
