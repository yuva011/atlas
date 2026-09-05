function deleteVehicle(vehicle)
  if GetResourceState("AdvancedParking") == "started" then
    exports.AdvancedParking:DeleteVehicle(vehicle, false)
  else
    DeleteEntity(vehicle)
  end
end

function getModelNameFromHash(modelHash)
  local displayName = GetDisplayNameFromVehicleModel(modelHash)
  local modelName = GetLabelText(displayName):lower()

  if not modelName then
    modelName = displayName:lower()
  end

  return modelName
end

function createPedForTarget(coords)
  lib.requestModel(Config.TargetPed)

  local pedModel = joaat(Config.TargetPed)
  local ped = CreatePed(
    GetPedType(pedModel),
    pedModel,
    coords.x,
    coords.y,
    coords.z,
    coords.w or 0,
    false,
    false
  )

  lib.waitFor(function()
    return DoesEntityExist(ped) or nil
  end)

  SetEntityInvincible(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetPedFleeAttributes(ped, 0, false)
  SetPedCombatAttributes(ped, 17, true)
  FreezeEntityPosition(ped, true)
  SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, true, true, false)
  SetPedCanRagdoll(ped, false)
  SetEntityProofs(ped, true, true, true, true, true, true, true, true)
  SetModelAsNoLongerNeeded(Config.TargetPed)

  return ped
end

function getVehicleType(model)
  local modelHash = convertModelToHash(model)
  local vehicleClass = GetVehicleClassFromName(modelHash)

  if IsThisModelABoat(modelHash) or vehicleClass == 14 then
    return "sea"
  end

  if IsThisModelAHeli(modelHash) or IsThisModelAPlane(modelHash) or vehicleClass == 16 then
    return "air"
  end

  return "car"
end

function filterVehiclesByType(vehicles, vehicleType)
  local filteredVehicles = {}

  for _, vehicle in ipairs(vehicles) do
    if getVehicleType(vehicle.hash) == vehicleType then
      filteredVehicles[#filteredVehicles + 1] = vehicle
    end
  end

  return filteredVehicles
end

function getVehicleDamage(vehicle)
  if not vehicle or vehicle == 0 then
    return false
  end

  local bodyHealth = 1000
  local engineHealth = 1000
  local deformation

  if Config.SaveVehicleDamage then
    bodyHealth = math.ceil(GetVehicleBodyHealth(vehicle))
    if type(bodyHealth) ~= "number" or bodyHealth < 0 then
      bodyHealth = 0
    end

    engineHealth = math.ceil(GetVehicleEngineHealth(vehicle))
    if type(engineHealth) ~= "number" or engineHealth < 0 then
      engineHealth = 0
    end

    if Config.AdvancedVehicleDamage then
      deformation = getVehicleDeformation(vehicle)
    end
  end

  return bodyHealth, engineHealth, deformation
end

RegisterNUICallback("close", function(_, cb)
  SetNuiFocus(false, false)
  cb(true)
end)
