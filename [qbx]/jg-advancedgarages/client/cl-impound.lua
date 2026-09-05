local impoundSearchRadius = 5.0
local selectedImpoundVehicle

local function getAvailableImpounds(vehicleType)
  local availableImpounds = {}
  local playerJob = Framework.Client.GetPlayerJob()

  if not playerJob then
    return {}
  end

  debugPrint("Player Job", "debug", playerJob)

  for impoundId, impound in pairs(Config.ImpoundLocations) do
    if not impound.job then
      print(("^1[WARNING] Heads up, %s does not have a job tied to it in the config"):format(impoundId))
    end

    if impound.job and isItemInList(impound.job, playerJob.name) and impound.type == vehicleType then
      availableImpounds[#availableImpounds + 1] = impoundId
    end
  end

  return availableImpounds
end

local function showImpoundForm()
  if Framework.Client.IsPlayerDead() then
    Framework.Client.Notify(Locale.playerIsDead, "error")
    return false
  end

  local playerCoords = GetEntityCoords(cache.ped)
  selectedImpoundVehicle = lib.getClosestVehicle(playerCoords, impoundSearchRadius, true)

  if not selectedImpoundVehicle or selectedImpoundVehicle == 0 then
    Framework.Client.Notify(Locale.moveCloserToVehicleError, "error")
    return false
  end

  local vehicleType = getVehicleType(GetEntityModel(selectedImpoundVehicle))
  local impoundLocations = getAvailableImpounds(vehicleType)

  if not impoundLocations or #impoundLocations == 0 then
    Framework.Client.Notify(Locale.actionNotAllowedError, "error")
    return false
  end

  local plate = Framework.Client.GetPlate(selectedImpoundVehicle)
  local model = GetEntityArchetypeName(selectedImpoundVehicle)
  local vehicleData = lib.callback.await("jg-advancedgarages:server:get-vehicle", false, model, plate)

  if not vehicleData then
    deleteVehicle(selectedImpoundVehicle)
    Framework.Client.Notify(Locale.vehicleImpoundSuccess .. " (NPC)", "success")
    return true
  end

  SetNuiFocus(true, true)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({
    type = "show-impound-form",
    impoundLocations = impoundLocations,
    plate = plate,
    config = Config,
    locale = Locale
  })
end

local function impoundVehicle(data)
  if not selectedImpoundVehicle or not DoesEntityExist(selectedImpoundVehicle) then
    return false
  end

  local plate = Framework.Client.GetPlate(selectedImpoundVehicle)
  local props = Framework.Client.GetVehicleProperties(selectedImpoundVehicle)
  local fuel = Framework.Client.VehicleGetFuel(selectedImpoundVehicle)
  local body, engine, deformation = getVehicleDamage(selectedImpoundVehicle)

  local success = lib.callback.await(
    "jg-advancedgarages:server:impound-vehicle",
    false,
    data,
    VehToNet(selectedImpoundVehicle),
    plate,
    props,
    fuel,
    body,
    engine,
    deformation
  )

  if not success then
    return false
  end

  TriggerEvent("jg-advancedgarages:client:ImpoundVehicle:config", selectedImpoundVehicle)
  return true
end

local function driveImpoundedVehicle(impoundId, originalGarageId, plate)
  local success, netId, vehicleData, vehicleProps, spawnCoords = lib.callback.await(
    "jg-advancedgarages:server:impound-remove-vehicle",
    false,
    impoundId,
    originalGarageId,
    plate,
    true
  )

  local vehicle = netId and NetToVeh(netId) or false

  if not success then
    return false
  end

  if Config.SpawnVehiclesWithServerSetter and not vehicle then
    print("^1There was a problem spawning in your vehicle")
    return false
  end

  if not vehicle and not Config.SpawnVehiclesWithServerSetter then
    vehicle = spawnVehicleClient(
      vehicleData and vehicleData.id or 0,
      vehicleData.model,
      plate,
      spawnCoords,
      not Config.DoNotSpawnInsideVehicle,
      vehicleProps,
      "personal"
    )

    if not vehicle then
      print("^1There was a problem spawning in your vehicle")
      return false
    end
  end

  if not vehicle then
    debugPrint("Value of `vehicle` is false", "warning")
    return false
  end

  lib.callback.await("jg-advancedgarages:server:impound-vehicle-driven-out", false, plate, VehToNet(vehicle))
  return true
end

RegisterNUICallback("impound-vehicle", function(data, cb)
  local result = impoundVehicle(data)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("impound-return-vehicle", function(data, cb)
  local result = lib.callback.await(
    "jg-advancedgarages:server:impound-remove-vehicle",
    false,
    data.impoundId,
    data.originalGarageId,
    data.plate,
    false
  )

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("impound-drive-vehicle", function(data, cb)
  local result = driveImpoundedVehicle(data.impoundId, data.originalGarageId, data.plate)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNetEvent("jg-advancedgarages:client:show-impound-form", showImpoundForm)
RegisterNetEvent("jg-advancedgarages:client:ImpoundVehicle", showImpoundForm)
