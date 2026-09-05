local storingVehicle = false
local cachedGarageVehicles = {}
local garageDistanceWarningCooldowns = {}
local GARAGE_DISTANCE_WARNING_COOLDOWN = 3000

local function notifyTooFarFromGarage(garageId)
  local now = GetGameTimer()
  local nextWarningAt = garageDistanceWarningCooldowns[garageId] or 0

  if now < nextWarningAt then
    return
  end

  garageDistanceWarningCooldowns[garageId] = now + GARAGE_DISTANCE_WARNING_COOLDOWN

  print(("^1The garage you are trying to open '%s' is a registered garage, and you are not at it's registered location."):format(garageId))
  print("^1If you were expecting to open a location via housing or another third-party integration, please note that this script is trying to open a garage with a name that is already registered.")
  print("^1Therefore, you will need to use a unique garageId in order to be able to open this garage.^0")
  Framework.Client.Notify("You are too far away from the garage", "error")
end

local function getTransferGarages(vehicleType, garageType, vehiclesType)
  local transferGarages = {}

  for garageId, garage in pairs(getAvailableGarageLocations()) do
    if garage.type == vehicleType and garage.garageType == "personal" then
      if garageType == "personal" or garage.vehiclesType == vehiclesType then
        transferGarages[#transferGarages + 1] = garageId
      end
    end
  end

  return transferGarages
end

local function refreshGarageVehicles(garageId, vehicleType)
  local vehicles = lib.callback.await("jg-advancedgarages:server:get-garage-vehicles", 2000, garageId) or cachedGarageVehicles
  cachedGarageVehicles = filterVehiclesByType(vehicles, vehicleType)

  for index, vehicle in ipairs(cachedGarageVehicles) do
    if vehicle.model then
      cachedGarageVehicles[index].model = type(vehicle.model) == "string" and vehicle.model or getModelNameFromHash(vehicle.hash)
      cachedGarageVehicles[index].vehicleLabel = Framework.Client.GetVehicleLabel(vehicle.model)
    else
      print(("^1Vehicle with plate %s does not have a model."):format(vehicle.plate))
    end
  end

  return cachedGarageVehicles
end

function openGarageMenu(garageId, vehicleType, spawnCoords)
  vehicleType = vehicleType or "car"

  if Framework.Client.IsPlayerDead() then
    Framework.Client.Notify(Locale.playerIsDead, "error")
    return
  end

  local garage = getAvailableGarageLocations()[garageId]

  if garage and garage.coords then
    local allowedDistance = garage.distance or 15.0
    local distance = #(GetEntityCoords(cache.ped) - garage.coords.xyz)

    if allowedDistance < distance then
      notifyTooFarFromGarage(garageId)
      return false
    end
  end

  if not garage then
    garage = {
      garageType = "personal",
      checkVehicleGarageId = Config.GarageUniqueLocations,
      enableInteriors = Config.PrivGarageEnableInteriors,
      unknown = true
    }
  end

  local nearbyPlayers = lib.callback.await("jg-advancedgarages:server:nearby-players", false, GetEntityCoords(cache.ped), 20.0, false)
  local transferGarages = getTransferGarages(vehicleType, garage.garageType, garage.vehiclesType)

  if garage.unknown then
    transferGarages[#transferGarages + 1] = garageId
  end

  refreshGarageVehicles(garageId, vehicleType)

  if GetResourceState("jg-vehiclemileage") == "started" then
    Config.MileageUnit = exports["jg-vehiclemileage"]:GetUnit()
  end

  if GetResourceState("jg-dealerships") == "started" then
    local ok = pcall(function()
      local dealershipLocale = exports["jg-dealerships"]:locale() or {}
      Locale = lib.table.merge(dealershipLocale, Locale, false)
    end)

    if not ok then
      print("^3[WARNING] You are running jg-dealerships, but you need to be using v1.2 or newer to use it with Advanced Garages v3. Some functionality may not work as expected.")
    end
  end

  SetNuiFocus(true, true)
  SendNUIMessage({
    type = "show-garage",
    garageId = garageId,
    vehicleType = vehicleType,
    vehicles = cachedGarageVehicles,
    checkVehicleGarageId = garage.checkVehicleGarageId,
    enableInteriors = garage.enableInteriors or false,
    isSpawnerGarage = garage.vehiclesType == "spawner",
    isJobGarage = garage.garageType == "job",
    transferGarages = transferGarages,
    onlinePlayers = nearbyPlayers,
    isImpound = garage.garageType == "impound",
    hasWhitelistedJob = garage.hasImpoundJob,
    spawnCoords = spawnCoords,
    config = Config,
    locale = Locale
  })
end

function driveVehicleOut(plate, garageId, spawnerIndex, spawnCoords)
  local garage = getAvailableGarageLocations()[garageId] or {}
  local success, netId, model, vehicleData, vehicleProps, vehicleSpawnCoords = lib.callback.await(
    "jg-advancedgarages:server:drive-vehicle-out",
    false,
    plate,
    garageId,
    spawnerIndex,
    spawnCoords
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
      model,
      plate,
      vehicleSpawnCoords,
      not Config.DoNotSpawnInsideVehicle,
      vehicleProps,
      garage.garageType
    )
  end

  if not vehicle then
    debugPrint("Value of `vehicle` is false", "warning")
    return false
  end

  if garage.vehiclesType ~= "spawner" then
    success = lib.callback.await(
      "jg-advancedgarages:server:vehicle-driven-out",
      false,
      garageId,
      VehToNet(vehicle),
      plate,
      vehicleData and vehicleData.in_garage == 0
    )

    if not success then
      deleteVehicle(vehicle)
    end
  end

  TriggerEvent("jg-advancedgarages:client:TakeOutVehicle:config", vehicle, vehicleData, garage.garageType)

  if garage.showLiveriesExtrasMenu then
    showLiveriesExtrasMenu(vehicle)
    return {noClose = true}
  end

  return true
end

local function storeVehicle(garageId, vehicleType)
  if storingVehicle then
    return false
  end

  vehicleType = vehicleType or "car"

  if Framework.Client.IsPlayerDead() then
    Framework.Client.Notify(Locale.playerIsDead, "error")
    return false
  end

  local vehicle = cache.vehicle
  local plate = Framework.Client.GetPlate(vehicle)

  if not vehicle or not plate then
    Framework.Client.Notify(Locale.notInsideVehicleError, "error")
    return false
  end

  if getVehicleType(GetEntityModel(vehicle)) ~= vehicleType then
    return Framework.Client.Notify(Locale.insertVehicleTypeError:gsub("%%{value}", vehicleType), "error")
  end

  local garage = getAvailableGarageLocations()[garageId]
  if garage and garage.garageType == "impound" then
    return false
  end

  storingVehicle = true

  local model = GetEntityArchetypeName(vehicle)
  local serverGarageId = garage and garage.vehiclesType ~= "spawner" and garageId or nil
  local vehicleData = lib.callback.await("jg-advancedgarages:server:get-vehicle", false, model, plate, serverGarageId)

  if (garage and garage.vehiclesType ~= "spawner" and not vehicleData) or (not garage or garage.vehiclesType ~= "spawner") and not vehicleData then
    Framework.Client.Notify(Locale.vehicleStoreError, "error")
    storingVehicle = false
    return false
  end

  local props = Framework.Client.GetVehicleProperties(vehicle)
  props.plate = plate

  local fuel = Framework.Client.VehicleGetFuel(vehicle)
  local body, engine, deformation = getVehicleDamage(vehicle)
  local verified = false

  local ok, err = pcall(function()
    TriggerEvent(
      "jg-advancedgarages:client:insert-vehicle-verification",
      vehicle,
      plate,
      garageId,
      vehicleData,
      props,
      fuel,
      body,
      engine,
      deformation,
      function(result)
        verified = result
      end
    )
  end)

  if not ok or not verified then
    storingVehicle = false
    debugPrint("jg-advancedgarages:client:insert-vehicle-verification returned false or pcall failed: " .. (err or ""), "debug")
    return false
  end

  local stored = lib.callback.await(
    "jg-advancedgarages:server:store-vehicle",
    false,
    garageId,
    VehToNet(vehicle),
    plate,
    props,
    fuel,
    body,
    engine,
    deformation
  )

  if not stored then
    storingVehicle = false
    return false
  end

  Framework.Client.VehicleRemoveKeys(plate, vehicle, garage and garage.garageType)

  if garage and garage.coords and (vehicleType == "air" or vehicleType == "sea") then
    local vehicleCoords = GetEntityCoords(vehicle)

    if #(garage.coords.xyz - vehicleCoords.xyz) > 0.5 then
      SetEntityCoords(cache.ped, garage.coords.x, garage.coords.y, garage.coords.z, false, false, false, false)
    end
  end

  TriggerEvent("jg-advancedgarages:client:InsertVehicle:config", vehicle, vehicleData, garage and garage.garageType)

  if GetResourceState("wasabi_ambulance") == "started" and garage and garage.garageType == "job" then
    local okDelete = pcall(function()
      exports.wasabi_ambulance:deleteStretcherFromVehicle(vehicle)
    end)

    if not okDelete then
      debugPrint("Wasabi Ambulance integration did not delete stretcher", "warning")
    end
  end

  Framework.Client.Notify(Locale.vehicleParkedSuccess, "success")
  storingVehicle = false
  return true
end

local function transferVehicle(transferType, garageId, plate, transferPlayerId, transferGarageId, fromGarageId)
  if transferType == "garage" and transferGarageId then
    return lib.callback.await("jg-advancedgarages:server:transfer-vehicle-garage", false, plate, garageId, fromGarageId, transferGarageId)
  end

  if transferType == "player" and transferPlayerId then
    local transferred = lib.callback.await("jg-advancedgarages:server:transfer-vehicle-to-player", false, plate, garageId, transferPlayerId)

    if not transferred then
      return false
    end

    TriggerEvent("jg-advancedgarages:client:TransferVehicle:config", plate, transferPlayerId)
    return true
  end

  print("^1[ERROR] invalid transfer type or invalid playerId/garageId")
  return false
end

lib.callback.register("jg-advancedgarages:client:leave-vehicle", function(netId, vehicleType)
  local vehicle = NetToVeh(netId)

  SetVehicleDoorsLocked(vehicle, 2)

  for seat = -1, 5 do
    local ped = GetPedInVehicleSeat(vehicle, seat)
    if ped then
      TaskLeaveVehicle(ped, vehicle, 0)
    end
  end

  Wait(vehicleType == "air" and 2500 or 1500)
end)

RegisterNUICallback("drive-vehicle", function(data, cb)
  local spawnCoords

  if data.spawnCoords then
    spawnCoords = vec(data.spawnCoords.x or 0, data.spawnCoords.y or 0, data.spawnCoords.z or 0, data.spawnCoords.w or 0)
  end

  local result = driveVehicleOut(data.plate, data.garageId, data.spawnerIndex, spawnCoords)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("garage-transfer-vehicle", function(data, cb)
  local result = transferVehicle(
    data.transferType,
    data.garageId,
    data.plate,
    data.transferPlayerId,
    data.transferGarageId,
    data.fromGarageId
  )

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("vehicle-set-nickname", function(data, cb)
  local result = lib.callback.await("jg-advancedgarages:server:vehicle-set-nickname", false, data.plate, data.nickname, data.garageId)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("finance-make-payment", function(data, cb)
  if GetResourceState("jg-dealerships") ~= "started" then
    return cb({error = true})
  end

  local result = lib.callback.await("jg-dealerships:server:finance-make-payment", false, data.plate, data.type)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("enter-garage-interior", function(data, cb)
  refreshGarageVehicles(data.garageId, data.vehicleType)

  local result = lib.callback.await("jg-advancedgarages:server:enter-interior", false, data.garageId, cachedGarageVehicles)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNetEvent("jg-advancedgarages:client:open-garage", openGarageMenu)
RegisterNetEvent("jg-advancedgarages:client:store-vehicle", storeVehicle)

RegisterNetEvent("jg-advancedgarages:client:ShowGarage", function(garageId, _, vehicleType)
  openGarageMenu(garageId, vehicleType)
end)

RegisterNetEvent("jg-advancedgarages:client:ShowGangGarage", function(garageId)
  openGarageMenu(garageId, "car")
end)

RegisterNetEvent("jg-advancedgarages:client:ShowJobGarage", function(garageId)
  openGarageMenu(garageId, "car")
end)

RegisterNetEvent("jg-advancedgarages:client:InsertVehicle", function(garageId, _, vehicleType)
  storeVehicle(garageId, vehicleType)
end)
