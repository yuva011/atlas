local function hasImpoundJob(playerSource, impoundId)
  local locations = getPlayerAvailableGarageLocations(playerSource)
  local impound = locations and locations[impoundId]

  return impound and impound.hasImpoundJob or false
end

local function getRetrievalDate(hoursFromNow)
  return os.date("%a %b %d %Y %H:%M:%S GMT%z", os.time() + (hoursFromNow * 3600))
end

local function decodeJson(value, fallback)
  if not value then
    return fallback
  end

  return json.decode(value) or fallback
end

local function getVehicleSpawnData(vehicleData)
  return {
    props = decodeJson(vehicleData[Framework.VehProps], false),
    fuel = vehicleData.fuel or 100.0,
    engine = vehicleData.engine or 1000.0,
    body = vehicleData.body or 1000.0,
    damage = decodeJson(vehicleData.damage, false)
  }
end

local function impoundVehicle(
  playerSource,
  plate,
  impoundId,
  reason,
  retrievable,
  retrievalDate,
  retrievalCost,
  vehicleProps,
  fuel,
  body,
  engine,
  damage
)
  if not plate then
    return false
  end

  if type(retrievalDate) == "number" then
    retrievalDate = getRetrievalDate(retrievalDate)
  end

  local vehicleData = getVehicleData(playerSource, false, plate)

  if not vehicleData then
    return false
  end

  local playerInfo = Framework.Server.GetPlayerInfo(playerSource)

  if not playerInfo then
    return false
  end

  local impoundData = json.encode({
    charname = playerInfo.name,
    reason = reason,
    retrieval_date = retrievalDate,
    retrieval_cost = retrievalCost,
    original_garage_id = vehicleData.garage_id
  })

  MySQL.update.await(Framework.Queries.ImpoundVehicle:format(Framework.VehiclesTable), {
    retrievable,
    impoundData,
    impoundId,
    fuel,
    body,
    engine,
    damage and json.encode(damage) or nil,
    plate
  })

  if Config.SaveVehiclePropsOnInsert and vehicleProps then
    MySQL.update.await(Framework.Queries.UpdateProps:format(Framework.VehiclesTable, Framework.VehProps), {
      json.encode(vehicleProps),
      plate
    })
  end

  Framework.Server.Notify(playerSource, Locale.vehicleImpoundSuccess, "success")

  sendWebhook(playerSource, Webhooks.Impound, "Vehicle Impounded", "success", {
    {key = "Plate", value = plate},
    {key = "Impounded by", value = playerInfo.name},
    {key = "Reason", value = reason},
    {key = "Retrievable by owner?", value = retrievable and "Yes" or "No"},
    {key = "Retrieval Date", value = retrievable and retrievalDate or "N/A"},
    {key = "Retrieval Cost", value = retrievable and retrievalCost or "N/A"}
  })

  return true
end

exports("impoundVehicle", impoundVehicle)

lib.callback.register(
  "jg-advancedgarages:server:impound-vehicle",
  function(playerSource, data, netId, plate, vehicleProps, fuel, body, engine, damage)
    if not hasImpoundJob(playerSource, data.impoundId) then
      return false
    end

    local success = impoundVehicle(
      playerSource,
      plate,
      data.impoundId,
      data.reason,
      data.retrievable,
      data.retrievalDate,
      data.retrievalCost,
      vehicleProps,
      fuel,
      body,
      engine,
      damage
    )

    if not success then
      return false
    end

    Globals.OutsideVehicles[plate] = nil

    if Config.Framework == "Qbox" then
      -- vehicle persistence disabled
    end

    deleteVehicle(NetworkGetEntityFromNetworkId(netId), netId, plate)
    return true
  end
)

local function payImpoundFeeIfNeeded(playerSource, vehicleData)
  local impounded = vehicleData.impound == true or vehicleData.impound == 1
  local retrievable = vehicleData.impound_retrievable == true or vehicleData.impound_retrievable == 1

  if not impounded or not retrievable then
    return true
  end

  local impoundData = decodeJson(vehicleData.impound_data, {})
  local retrievalCost = impoundData.retrieval_cost or 0

  if retrievalCost <= 0 then
    return true
  end

  if not Framework.Server.PlayerRemoveMoney(playerSource, retrievalCost, "bank") then
    return false
  end

  if Config.ImpoundFeesSocietyFund then
    Framework.Server.PayIntoSocietyFund(Config.ImpoundFeesSocietyFund, retrievalCost)
  end

  return true
end

local function validateImpoundDistance(playerSource, impoundId, impound)
  if not impound or not impound.coords then
    return true
  end

  local maxDistance = impound.distance or 15.0
  local playerCoords = GetEntityCoords(GetPlayerPed(playerSource))
  local distance = #(playerCoords - impound.coords.xyz)

  if distance <= maxDistance then
    return true
  end

  Framework.Server.Notify(playerSource, "You are too far away from the impound", "error")
  return false
end

local function spawnImpoundedVehicle(playerSource, impoundId, impound, plate, vehicleData, vehicleProps)
  if not validateImpoundDistance(playerSource, impoundId, impound) then
    return false
  end

  local spawnCoords = findVehicleSpawnCoords(impound.spawn)

  if not spawnCoords then
    Framework.Server.Notify(playerSource, "Impound location is missing/has no valid spawn coords", "error")
    print("^1[ERROR] Impound is missing/has no valid spawn coords", impoundId)
    return false
  end

  if not Config.SpawnVehiclesWithServerSetter then
    return nil, spawnCoords
  end

  local netId = spawnVehicleServer(
    playerSource,
    vehicleData.id or 0,
    vehicleData.model,
    plate,
    spawnCoords,
    not Config.DoNotSpawnInsideVehicle,
    vehicleProps,
    "personal"
  )

  if not netId then
    Framework.Server.Notify(playerSource, "Could not spawn vehicle - vehicle was not not removed from impound", "error")
    return false
  end

  Globals.OutsideVehicles[plate] = netId
  return netId, spawnCoords
end

lib.callback.register(
  "jg-advancedgarages:server:impound-remove-vehicle",
  function(playerSource, impoundId, originalGarageId, plate, driveOut)
    local locations = getPlayerAvailableGarageLocations(playerSource)
    local impound = locations and locations[impoundId]

    if not impound then
      return false
    end

    local vehicleData = getVehicleData(playerSource, false, plate)

    if not vehicleData then
      Framework.Server.Notify(playerSource, "Could not get vehicle data from database", "error")
      return false
    end

    local vehicleProps = getVehicleSpawnData(vehicleData)

    if not hasImpoundJob(playerSource, impoundId) and not payImpoundFeeIfNeeded(playerSource, vehicleData) then
      return false
    end

    local netId
    local spawnCoords

    if driveOut then
      netId, spawnCoords = spawnImpoundedVehicle(playerSource, impoundId, impound, plate, vehicleData, vehicleProps)

      if netId == false then
        return false
      end
    end

    MySQL.update.await(Framework.Queries.ImpoundReturnToGarage:format(Framework.VehiclesTable), {
      originalGarageId,
      driveOut and 0 or 1,
      plate
    })

    if not driveOut then
      Framework.Server.Notify(playerSource, Locale.vehicleImpoundReturnedToOwnerSuccess, "success")
    end

    return true, netId, vehicleData, vehicleProps, spawnCoords
  end
)

lib.callback.register("jg-advancedgarages:server:impound-vehicle-driven-out", function(_, plate, netId)
  Globals.OutsideVehicles[plate] = netId

  if Config.Framework == "Qbox" then
    -- vehicle persistence disabled
  end
end)

lib.addCommand(Config.ImpoundCommand, { restricted = false, help = 'Impound A Vehicle (Police Only)' }, function(source)
  local jobData = Framework.Server.GetPlayerJob(source)
  local job = jobData and jobData.name
  local pdJobs = { sasp = true, bcso = true, lspd = true, saspr = true }
  if not pdJobs[job] then
    Framework.Server.Notify(source, "Only PD officers can impound vehicles", "error")
    return
  end
  TriggerClientEvent("jg-advancedgarages:client:show-impound-form", source)
end)
