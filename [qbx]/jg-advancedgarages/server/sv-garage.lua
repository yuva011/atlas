local function canUseGangFramework()
  return Config.Framework ~= "ESX" or Config.GangEnableCustomESXIntegration
end

local function decodeJson(value, fallback)
  if not value then
    return fallback
  end

  return json.decode(value) or fallback
end

local function truthyDatabaseValue(value)
  return value == true or value == 1 or value == "1" or value == "true"
end

local function falsyDatabaseValue(value)
  return value == false or value == 0 or value == "0" or value == "false"
end

local function getPlayerGang(playerSource)
  if not canUseGangFramework() then
    return nil
  end

  return Framework.Server.GetPlayerGang(playerSource)
end

local function getGarageOwnerIdentifier(playerSource, garageId, locations)
  local identifier = Framework.Server.GetPlayerIdentifier(playerSource)
  local playerJob = Framework.Server.GetPlayerJob(playerSource)
  local playerGang = getPlayerGang(playerSource)

  debugPrint("Player Identifier", "debug", identifier)
  debugPrint("Player Gang", "debug", playerGang)
  debugPrint("Player Job", "debug", playerJob)

  locations = locations or getPlayerAvailableGarageLocations(playerSource)
  local garage = locations and locations[garageId]

  if not garage then
    return identifier
  end

  if playerJob and garage.garageType == "job" and garage.vehiclesType ~= "personal" then
    return playerJob.name
  end

  if playerGang and garage.garageType == "gang" and garage.vehiclesType ~= "personal" then
    return playerGang.name
  end

  return identifier
end

function getVehicleData(playerSource, expectedModel, plate, garageId, ownerIdentifier)
  local vehicleData

  if not garageId then
    vehicleData = MySQL.prepare.await(Framework.Queries.GetVehicleNoIdentifier:format(Framework.VehiclesTable), {plate}) or false
  else
    ownerIdentifier = ownerIdentifier or getGarageOwnerIdentifier(playerSource, garageId)

    vehicleData = MySQL.prepare.await(
      Framework.Queries.GetVehicle:format(Framework.VehiclesTable, Framework.PlayerIdentifier),
      {ownerIdentifier, plate}
    )
  end

  if not vehicleData then
    debugPrint("Vehicle data is nil", "warning", plate)
    return false
  end

  vehicleData.id = vehicleData.id or 0
  vehicleData.model = Framework.Server.GetModelColumn(vehicleData)
  vehicleData.hash = convertModelToHash(vehicleData.model)

  if expectedModel and Config.CheckVehicleModel then
    local expectedHash = joaat(expectedModel)

    if vehicleData.model ~= expectedModel and vehicleData.hash ~= expectedHash then
      debugPrint("Plate has been found, but model does not match the one in the DB", "warning")
      return false
    end
  end

  return vehicleData
end

lib.callback.register("jg-advancedgarages:server:get-vehicle", function(playerSource, expectedModel, plate, garageId)
  return getVehicleData(playerSource, expectedModel, plate, garageId)
end)

local function getDefaultGarage()
  return {
    garageType = "personal",
    checkVehicleGarageId = Config.GarageUniqueLocations,
    enableInteriors = Config.PrivGarageEnableInteriors
  }
end

local function appendSpawnerVehicles(vehicles, garage)
  if not garage.vehicles then
    return
  end

  for index, vehicle in ipairs(garage.vehicles) do
    vehicle.spawnerModel = vehicle.model
    vehicle.spawnerIndex = index
    vehicle.spawner = true
    vehicles[#vehicles + 1] = vehicle
  end
end

local function fetchGarageVehicles(playerSource, garageId, garage, identifier, playerJob, playerGang)
  if playerJob and garage.garageType == "job" and garage.vehiclesType ~= "personal" then
    if garage.vehiclesType == "owned" then
      return MySQL.query.await(
        Framework.Queries.GetJobVehicles:format(Framework.VehiclesTable, Framework.PlayerIdentifier),
        {playerJob.name, playerJob.grade or 0}
      ) or {}
    end

    if garage.vehiclesType == "spawner" then
      local vehicles = {}
      local pdJobs = { sasp = true, bcso = true, lspd = true, saspr = true }
      if pdJobs[playerJob.name] then
        local grade = playerJob.grade or 0
        local result = MySQL.query.await('SELECT vehicle_model, enabled FROM pd_vehicle_access WHERE department = ? AND grade = ?', { playerJob.name, grade })
        local allowedModels = {}
        if result and #result > 0 then
          for _, row in ipairs(result) do
            if row.enabled == true then
              allowedModels[row.vehicle_model] = true
            end
          end
          for index, vehicle in ipairs(garage.vehicles) do
            if allowedModels[vehicle.model] then
              vehicle.spawnerModel = vehicle.model
              vehicle.spawnerIndex = index
              vehicle.spawner = true
              vehicles[#vehicles + 1] = vehicle
            end
          end
        end
      else
        appendSpawnerVehicles(vehicles, garage)
      end
      return vehicles
    end
  end

  if playerGang and garage.garageType == "gang" and garage.vehiclesType ~= "personal" then
    if garage.vehiclesType == "owned" then
      return MySQL.query.await(
        Framework.Queries.GetGangVehicles:format(Framework.VehiclesTable, Framework.PlayerIdentifier),
        {playerGang.name, playerGang.grade or 0}
      ) or {}
    end

    if garage.vehiclesType == "spawner" then
      local vehicles = {}
      appendSpawnerVehicles(vehicles, garage)
      return vehicles
    end
  end

  if garage.garageType == "impound" then
    if garage.hasImpoundJob then
      return MySQL.query.await(
        Framework.Queries.GetImpoundVehiclesWhitelist:format(Framework.VehiclesTable),
        {garageId}
      ) or {}
    end

    return MySQL.query.await(
      Framework.Queries.GetImpoundVehiclesPublic:format(
        Framework.VehiclesTable,
        Framework.PlayerIdentifier,
        Framework.PlayerIdentifier,
        Framework.PlayerIdentifier
      ),
      {garageId, identifier, playerJob and playerJob.name or "-", playerGang and playerGang.name or "-"}
    ) or {}
  end

  return MySQL.query.await(
    Framework.Queries.GetVehicles:format(Framework.VehiclesTable, Framework.PlayerIdentifier),
    {identifier}
  ) or {}
end

local function hasRequiredVehicleGrade(vehicle, playerJob, playerGang)
  if vehicle.minJobGrade then
    return playerJob and playerJob.grade >= vehicle.minJobGrade
  end

  if vehicle.minGangGrade then
    return playerGang and playerGang.grade >= vehicle.minGangGrade
  end

  return true
end

local function formatGarageVehicle(index, vehicle, garage, playerJob, playerGang)
  local model = vehicle.spawnerModel or Framework.Server.GetModelColumn(vehicle)

  if not model or not hasRequiredVehicleGrade(vehicle, playerJob, playerGang) then
    return nil
  end

  local props = decodeJson(vehicle[Framework.VehProps] or "{}", false)
  local spawned = false

  if not garage.infiniteSpawns and vehicle.plate then
    spawned = isVehicleSpawned(vehicle.plate)
  end

  return {
    id = index,
    hash = convertModelToHash(model),
    model = model,
    props = props,
    nickname = vehicle.nickname or false,
    plate = vehicle.plate or false,
    blacklisted = model and isVehicleTransferBlacklisted(model) or false,
    impound = truthyDatabaseValue(vehicle.impound),
    impoundRetrievable = truthyDatabaseValue(vehicle.impound_retrievable),
    impoundData = vehicle.impound_data,
    mileage = vehicle.mileage,
    needsServicing = props and doesVehicleNeedServicing(props) or false,
    garageId = vehicle.garage_id,
    inGarage = not falsyDatabaseValue(vehicle.in_garage),
    isSpawned = spawned,
    fuel = vehicle.fuel or 100.0,
    engine = vehicle.engine or 1000.0,
    body = vehicle.body or 1000.0,
    financed = truthyDatabaseValue(vehicle.financed),
    financeData = truthyDatabaseValue(vehicle.financed) and decodeJson(vehicle.finance_data or "{}", false) or false,
    spawnerIndex = vehicle.spawnerIndex or false
  }
end

lib.callback.register("jg-advancedgarages:server:get-garage-vehicles", function(playerSource, garageId)
  local identifier = Framework.Server.GetPlayerIdentifier(playerSource)

  if not identifier then
    debugPrint("Player identifier is nil", "warning")
    return {}
  end

  local playerJob = Framework.Server.GetPlayerJob(playerSource)
  local playerGang = getPlayerGang(playerSource)

  debugPrint("Player Identifier", "debug", identifier)
  debugPrint("Player Gang", "debug", playerGang)
  debugPrint("Player Job", "debug", playerJob)

  local locations = getPlayerAvailableGarageLocations(playerSource)
  local garage = locations and locations[garageId] or getDefaultGarage()
  local rows = fetchGarageVehicles(playerSource, garageId, garage, identifier, playerJob, playerGang)
  local vehicles = {}

  for index, vehicle in ipairs(rows) do
    local formatted = formatGarageVehicle(index, vehicle, garage, playerJob, playerGang)

    if formatted then
      vehicles[#vehicles + 1] = formatted
    end
  end

  return vehicles
end)

local function getVehicleSpawnData(vehicleData)
  return {
    props = decodeJson(vehicleData[Framework.VehProps], false),
    fuel = vehicleData.fuel or 100.0,
    engine = vehicleData.engine or 1000.0,
    body = vehicleData.body or 1000.0,
    damage = decodeJson(vehicleData.damage, false)
  }
end

local function getPlayerCoordsAsVector4(playerSource)
  local ped = GetPlayerPed(playerSource)
  local coords = GetEntityCoords(ped)

  return vector4(coords.x, coords.y, coords.z, GetEntityHeading(ped))
end

local function isPlayerNearGarage(playerSource, garage, errorMessage)
  if not garage or not garage.coords then
    return true
  end

  local maxDistance = garage.distance or 15.0
  local distance = #(GetEntityCoords(GetPlayerPed(playerSource)) - garage.coords.xyz)

  if distance <= maxDistance then
    return true
  end

  Framework.Server.Notify(playerSource, errorMessage, "error")
  return false
end

lib.callback.register(
  "jg-advancedgarages:server:store-vehicle",
  function(playerSource, garageId, netId, plate, vehicleProps, fuel, body, engine, damage)
    local locations = getPlayerAvailableGarageLocations(playerSource)
    local garage = locations and locations[garageId]
    local vehiclesType = garage and garage.vehiclesType

    if vehiclesType ~= "spawner" then
      local identifier = Framework.Server.GetPlayerIdentifier(playerSource)

      if garage and garage.garageType == "job" and garage.vehiclesType ~= "personal" then
        identifier = garage.job
      elseif garage and garage.garageType == "gang" and garage.vehiclesType ~= "personal" then
        identifier = garage.gang
      end

      Globals.OutsideVehicles[plate] = nil

      -- vehicle persistence disabled

      debugPrint(
        "Storing vehicle ",
        "debug",
        "Identifier:",
        identifier,
        "Plate:",
        plate,
        "Engine:",
        engine,
        "Body:",
        body,
        "Fuel:",
        fuel,
        "Damage:",
        damage or {}
      )

      MySQL.update.await(Framework.Queries.StoreVehicle:format(Framework.VehiclesTable, Framework.PlayerIdentifier), {
        garageId,
        fuel or 0,
        body or 0,
        engine or 0,
        damage and json.encode(damage) or nil,
        identifier,
        plate
      })

      sendWebhook(playerSource, Webhooks.VehicleTakeOutAndInsert, "Vehicle stored in garage", "success", {
        {key = "Plate", value = plate},
        {key = "Garage", value = garageId}
      })

      if Config.SaveVehiclePropsOnInsert and vehicleProps then
        MySQL.update.await(Framework.Queries.UpdateProps:format(Framework.VehiclesTable, Framework.VehProps), {
          json.encode(vehicleProps),
          plate
        })
      end
    end

    lib.callback.await("jg-advancedgarages:client:leave-vehicle", playerSource, netId, garage and garage.type)
    deleteVehicle(NetworkGetEntityFromNetworkId(netId), netId, plate)

    return true
  end
)

local function getSpawnerVehicleData(garage, spawnerIndex, plate)
  local spawnerVehicle = garage and garage.vehicles and garage.vehicles[spawnerIndex]

  if not spawnerIndex or not spawnerVehicle then
    return nil
  end

  if plate == "" then
    plate = false
  elseif plate then
    plate = plate:upper()
  end

  local props = {}

  if plate then
    props.plate = plate
  end

  if spawnerVehicle.maxMods then
    props.modEngine = 3
    props.modBrakes = 2
    props.modTransmission = 2
    props.modSuspension = 3
    props.modTurbo = true
  end

  return spawnerVehicle.model, nil, {
    props = props,
    fuel = 100.0,
    engine = 1000.0,
    body = 1000.0,
    damage = false,
    livery = spawnerVehicle.livery,
    extras = spawnerVehicle.extras,
    clean = true
  }, plate
end

local function getOwnedVehicleTakeoutData(playerSource, plate, garageId, ownerIdentifier)
  if not plate then
    Framework.Server.Notify(playerSource, "Vehicle plate is nil", "error")
    return nil
  end

  local vehicleData = getVehicleData(playerSource, false, plate, garageId, ownerIdentifier)

  if not vehicleData then
    Framework.Server.Notify(playerSource, "Could not get the vehicle's data, see console", "error")
    print("^1[ERROR] Could not get vehicle data - plate does not exist on lookup, it does not belong to you or is corrupted?")
    return nil
  end

  return vehicleData.model, vehicleData, getVehicleSpawnData(vehicleData), plate
end

lib.callback.register(
  "jg-advancedgarages:server:drive-vehicle-out",
  function(playerSource, plate, garageId, spawnerIndex, requestedSpawnCoords)
    local locations = getPlayerAvailableGarageLocations(playerSource)
    local ownerIdentifier = getGarageOwnerIdentifier(playerSource, garageId, locations)
    local garage = locations and locations[garageId]
    local allowInfiniteSpawns = (garage and garage.infiniteSpawns) or Config.AllowInfiniteVehicleSpawns
    local vehiclesType = garage and garage.vehiclesType

    if not allowInfiniteSpawns and vehiclesType ~= "spawner" and plate and isVehicleSpawned(plate) then
      Framework.Server.Notify(playerSource, "Vehicle is already out", "error")
      return false
    end

    if not isPlayerNearGarage(playerSource, garage, "You are too far away from the garage") then
      return false
    end

    local spawnCoords = garage and garage.spawn and findVehicleSpawnCoords(garage.spawn) or requestedSpawnCoords
    spawnCoords = spawnCoords or getPlayerCoordsAsVector4(playerSource)

    local model
    local vehicleData
    local vehicleProps

    if vehiclesType == "spawner" then
      model, vehicleData, vehicleProps, plate = getSpawnerVehicleData(garage, spawnerIndex, plate)

      if not model then
        return false
      end
    else
      model, vehicleData, vehicleProps, plate = getOwnedVehicleTakeoutData(playerSource, plate, garageId, ownerIdentifier)

      if not model then
        return false
      end
    end

    local verified = lib.callback.await(
      "jg-advancedgarages:client:takeout-vehicle-verification",
      playerSource,
      plate,
      vehicleData or {},
      garageId
    )

    if not verified then
      debugPrint("jg-advancedgarages:client:takeout-vehicle-verification returned false", "debug")
      return false
    end

    local netId

    if Config.SpawnVehiclesWithServerSetter then
      netId = spawnVehicleServer(
        playerSource,
        vehicleData and vehicleData.id or 0,
        model,
        plate,
        spawnCoords,
        not Config.DoNotSpawnInsideVehicle,
        vehicleProps,
        garage and garage.garageType
      )

      if not netId then
        Framework.Server.Notify(playerSource, "Could not spawn vehicle with Config.SpawnVehiclesWithServerSetter", "error")
        return false
      end
    end

    return true, netId, model, vehicleData, vehicleProps, spawnCoords
  end
)

lib.callback.register("jg-advancedgarages:server:vehicle-driven-out", function(playerSource, garageId, netId, plate, chargeReturnCost)
  local ownerIdentifier = getGarageOwnerIdentifier(playerSource, garageId)

  if chargeReturnCost then
    if not Framework.Server.PlayerRemoveMoney(playerSource, Config.GarageVehicleReturnCost, "bank") then
      return false
    end

    if Config.GarageVehicleReturnCostSocietyFund then
      Framework.Server.PayIntoSocietyFund(Config.GarageVehicleReturnCostSocietyFund, Config.GarageVehicleReturnCost)
    end
  end

  Globals.OutsideVehicles[plate] = netId

  -- vehicle persistence disabled

  MySQL.update.await(Framework.Queries.VehicleDriveOut:format(Framework.VehiclesTable, Framework.PlayerIdentifier), {
    ownerIdentifier,
    plate
  })

  if GetResourceState("jpr-housingsystem") == "started" then
    MySQL.query.await("DELETE FROM jpr_housingsystem_houses_garages WHERE plate = ?", {plate})
  end

  sendWebhook(playerSource, Webhooks.VehicleTakeOutAndInsert, "Vehicle taken out of garage", "success", {
    {key = "Plate", value = plate},
    {key = "Garage", value = garageId}
  })

  return true
end)

lib.callback.register("jg-advancedgarages:server:transfer-vehicle-to-player", function(playerSource, plate, garageId, targetPlayerId)
  local verified = lib.callback.await("jg-advancedgarages:client:transfer-vehicle-verification", playerSource, targetPlayerId, plate)

  if not verified then
    return false
  end

  local currentIdentifier = getGarageOwnerIdentifier(playerSource, garageId)
  local targetIdentifier = Framework.Server.GetPlayerIdentifier(targetPlayerId)

  if not targetIdentifier then
    Framework.Server.Notify(playerSource, Locale.playerNotOnlineError, "error")
    return false
  end

  local targetInfo = Framework.Server.GetPlayerInfo(targetPlayerId)
  local targetName = targetInfo and targetInfo.name

  MySQL.update.await(
    Framework.Queries.UpdatePlayerId:format(Framework.VehiclesTable, Framework.PlayerIdentifier, Framework.PlayerIdentifier),
    {targetIdentifier, currentIdentifier, plate}
  )

  if GetResourceState("jpr-housingsystem") == "started" then
    MySQL.query.await("DELETE FROM jpr_housingsystem_houses_garages WHERE plate = ?", {plate})
  end

  sendWebhook(playerSource, Webhooks.VehiclePlayerTransfer, "Vehicle transferred to another player", "warning", {
    {key = "Plate", value = plate},
    {key = "Recipient", value = targetName}
  })

  return true
end)

lib.callback.register("jg-advancedgarages:server:transfer-vehicle-garage", function(playerSource, plate, garageId, fromGarageId, toGarageId)
  local verified = lib.callback.await(
    "jg-advancedgarages:client:transfer-garage-verification",
    playerSource,
    garageId,
    fromGarageId,
    toGarageId,
    plate
  )

  if not verified then
    return false
  end

  local ownerIdentifier = getGarageOwnerIdentifier(playerSource, fromGarageId)
  local targetGarage = getPlayerAvailableGarageLocations(playerSource)
  targetGarage = targetGarage and targetGarage[toGarageId]

  if not targetGarage and Config.DisableTransfersToUnregisteredGarages then
    Framework.Server.Notify(playerSource, "Transfers to this garage are disabled, please contact an admin", "error")
    return false
  end

  if Config.GarageVehicleTransferCost then
    if not Framework.Server.PlayerRemoveMoney(playerSource, Config.GarageVehicleTransferCost, "bank") then
      print("^1[ERROR] Could not remove player money. Attempted to remove amount:", Config.GarageVehicleTransferCost)
      return false
    end
  end

  MySQL.update.await(Framework.Queries.UpdateGarageId:format(Framework.VehiclesTable, Framework.PlayerIdentifier), {
    toGarageId,
    ownerIdentifier,
    plate
  })

  sendWebhook(playerSource, Webhooks.VehicleGarageTransfer, "Vehicle transferred to another garage", "warning", {
    {key = "Plate", value = plate},
    {key = "From Garage", value = fromGarageId},
    {key = "To Garage", value = toGarageId}
  })

  return true
end)

lib.callback.register("jg-advancedgarages:server:vehicle-set-nickname", function(playerSource, plate, nickname, garageId)
  local ownerIdentifier = getGarageOwnerIdentifier(playerSource, garageId)

  MySQL.update.await(Framework.Queries.UpdateVehicleNickname:format(Framework.VehiclesTable, Framework.PlayerIdentifier), {
    nickname,
    ownerIdentifier,
    plate
  })

  return true
end)

exports("getAllGarages", function()
  local garages = {}

  for garageId, garage in pairs(getAllGaragesAndImpounds()) do
    garages[#garages + 1] = {
      name = garageId,
      label = garageId,
      type = garage.type,
      takeVehicle = garage.coords,
      putVehicle = garage.coords,
      spawnPoint = garage.spawn,
      showBlip = not garage.hideBlip,
      blipName = garageId,
      blipNumber = garage.blip.id,
      blipColor = garage.blip.color,
      vehicle = garage.type
    }
  end

  return garages
end)
