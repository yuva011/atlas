local function getVehicleGameName(modelHash)
  local vehicleClass = GetVehicleClassFromName(modelHash)

  if IsThisModelACar(modelHash) or IsThisModelAQuadbike(modelHash) or vehicleClass == 5 then
    return "automobile"
  end

  if IsThisModelABicycle(modelHash) or IsThisModelABike(modelHash) then
    return "bike"
  end

  if IsThisModelABoat(modelHash) then
    return "boat"
  end

  if IsThisModelAHeli(modelHash) or vehicleClass == 16 then
    return "heli"
  end

  if IsThisModelAPlane(modelHash) then
    return "plane"
  end

  if IsThisModelATrain(modelHash) then
    return "train"
  end

  if vehicleClass == 14 then
    return "submarine"
  end

  return "trailer"
end

local function applyVehicleData(vehicle, vehicleData)
  if type(vehicleData) ~= "table" then
    return false
  end

  if type(vehicleData.props) == "table" then
    Framework.Client.SetVehicleProperties(vehicle, vehicleData.props)
    SetVehicleFixed(vehicle)
    Framework.Client.SetVehicleProperties(vehicle, vehicleData.props)
  end

  Framework.Client.VehicleSetFuel(vehicle, vehicleData.fuel or 100.0)
  SetVehicleEngineHealth(vehicle, vehicleData.engine and Config.SaveVehicleDamage and vehicleData.engine + 0.0 or 1000.0)
  SetVehicleBodyHealth(vehicle, vehicleData.body and Config.SaveVehicleDamage and vehicleData.body + 0.0 or 1000.0)

  if vehicleData.damage and Config.AdvancedVehicleDamage then
    setVehicleDeformation(vehicle, vehicleData.damage)
  end

  SetVehicleModKit(vehicle, 0)

  if type(vehicleData.livery) == "number" then
    SetVehicleMod(vehicle, 48, vehicleData.livery, false)
    SetVehicleLivery(vehicle, vehicleData.livery)
  end

  if type(vehicleData.extras) == "table" then
    for extraId = 1, 14 do
      if DoesExtraExist(vehicle, extraId) then
        SetVehicleExtra(vehicle, extraId, isItemInList(vehicleData.extras, extraId) and 0 or 1)
        SetVehicleFixed(vehicle)
      end
    end
  end

  if vehicleData.clean then
    SetVehicleDirtLevel(vehicle, 0.0)
  end

  return not NetworkGetEntityIsNetworked(vehicle)
end

local function requestVehicleSpawnDetails(model)
  local modelHash = convertModelToHash(model)
  local gameName = getVehicleGameName(modelHash)

  if not IsModelInCdimage(modelHash) then
    Framework.Client.Notify("Vehicle model does not exist - contact an admin", "error")
    print(("^1Vehicle model %s does not exist"):format(model))
    return false
  end

  local hasSeats = GetVehicleModelNumberOfSeats(modelHash) > 0

  if plate and plate ~= "" and not isValidGTAPlate(plate) then
    Framework.Client.Notify("This vehicle's plate is invalid (hit F8 for more details)", "error")
    print(("^1This vehicle is trying to spawn with the plate '%s' which is invalid for a GTA vehicle plate"):format(plate:upper()))
    print("^1Vehicle plates must be 8 characters long maximum, and can contain ONLY numbers, letters and spaces")
    return false
  end

  lib.requestModel(modelHash, 60000)

  if IsPedRagdoll(cache.ped) then
    Framework.Client.Notify("You are currently in a ragdoll state", "error")
    SetModelAsNoLongerNeeded(modelHash)
    return false
  end

  return modelHash, gameName, hasSeats
end

local function finishVehicleSpawn(vehicle, vehicleId, warpIntoVehicle, plate, vehicleData, keyType)
  if not vehicle or vehicle == 0 then
    Framework.Client.Notify("Could not spawn vehicle - hit F8 for details", "error")
    print("^1Vehicle does not exist (vehicle = 0)")
    return false
  end

  if IsPedRagdoll(cache.ped) then
    Framework.Client.Notify("You are currently in a ragdoll state", "error")
    SetModelAsNoLongerNeeded(GetEntityModel(vehicle))
    return false
  end

  if warpIntoVehicle then
    ClearPedTasks(cache.ped)

    local success = pcall(function()
      lib.waitFor(function()
        if GetPedInVehicleSeat(vehicle, -1) == cache.ped then
          return true
        end

        TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
      end, nil, 5000)
    end)

    if not success then
      print("^1[ERROR] Could not warp you into the vehicle^0")
      return false
    end
  end

  if plate and plate ~= "" then
    SetVehicleNumberPlateText(vehicle, plate)
  end

  if type(vehicleData) == "table" then
    applyVehicleData(vehicle, vehicleData)
  end

  if GetResourceState("brazzers-fakeplates") == "started" then
    local fakePlate = lib.callback.await("jg-advancedgarages:server:brazzers-get-fakeplate-from-plate", false, plate)
    if fakePlate then
      plate = fakePlate
      SetVehicleNumberPlateText(vehicle, fakePlate)
    end
  end

  if not plate or plate == "" then
    plate = Framework.Client.GetPlate(vehicle)
  end

  if not plate or plate == "" then
    print("^1[ERROR] The game thinks the vehicle has no plate - absolutely no idea how you've managed this")
    return false
  end

  Entity(vehicle).state:set("vehicleid", vehicleId, true)
  Framework.Client.VehicleGiveKeys(plate, vehicle, keyType)

  return true
end

local function onServerVehicleCreated(netId, teleportCoords, warpIntoVehicle, modelHash, vehicleId, plate, vehicleData, keyType)
  SetModelAsNoLongerNeeded(modelHash)

  if not netId then
    Framework.Client.Notify("Could not spawn vehicle - hit F8 for details", "error")
    print("^1Server returned false for netId")
    return false
  end

  lib.waitFor(function()
    return NetworkDoesNetworkIdExist(netId) and NetworkDoesEntityExistWithNetworkId(netId) or nil
  end, "Timed out while waiting for a server-setter netId to exist on client", 10000)

  local vehicle = NetToVeh(netId)

  lib.waitFor(function()
    return DoesEntityExist(vehicle) or nil
  end, "Timed out while waiting for a server-setter vehicle to exist on client", 10000)

  if teleportCoords then
    SetEntityCoords(cache.ped, teleportCoords.x, teleportCoords.y, teleportCoords.z, false, false, false, false)
  end

  if not finishVehicleSpawn(vehicle, vehicleId, warpIntoVehicle, plate, vehicleData, keyType) then
    DeleteEntity(vehicle)
    return false
  end

  return vehicle
end

function createClientVehicle(modelHash, coords, plate, networked)
  lib.requestModel(modelHash, 60000)

  local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, coords.w, networked or false, true)

  lib.waitFor(function()
    return DoesEntityExist(vehicle) or nil
  end, "Timed out while trying to spawn in vehicle (client)", 10000)

  SetModelAsNoLongerNeeded(modelHash)

  if plate and plate ~= "" then
    SetVehicleNumberPlateText(vehicle, plate)
  end

  return vehicle
end

function spawnVehicleClient(vehicleId, model, plate, coords, warpIntoVehicle, vehicleData, keyType)
  if Config.SpawnVehiclesWithServerSetter then
    print("^1This function is disabled as client spawning is enabled")
    return false
  end

  local modelHash, _, hasSeats = requestVehicleSpawnDetails(model)
  if not modelHash then
    return false
  end

  local vehicle = createClientVehicle(modelHash, coords, plate, true)
  if not vehicle then
    return false
  end

  local shouldWarp = hasSeats and warpIntoVehicle or nil
  if not finishVehicleSpawn(vehicle, vehicleId, shouldWarp, plate, vehicleData, keyType) then
    DeleteEntity(vehicle)
    return false
  end

  return vehicle
end

AddStateBagChangeHandler("vehInit", "", function(bagName, _, value)
  if not value then
    return
  end

  local vehicle = GetEntityFromStateBagName(bagName)
  if vehicle == 0 then
    return
  end

  lib.waitFor(function()
    return not IsEntityWaitingForWorldCollision(vehicle)
  end)

  if NetworkGetEntityOwner(vehicle) ~= cache.playerId then
    return
  end

  local state = Entity(vehicle).state
  SetVehicleOnGroundProperly(vehicle)

  SetTimeout(0, function()
    state:set("vehInit", nil, true)
  end)
end)

AddStateBagChangeHandler("vehCreatedApplyProps", "", function(bagName, _, value)
  if not value then
    return
  end

  local vehicle = GetEntityFromStateBagName(bagName)
  if vehicle == 0 then
    return
  end

  SetTimeout(0, function()
    local state = Entity(vehicle).state

    for _ = 1, 10 do
      if NetworkGetEntityOwner(vehicle) == cache.playerId and applyVehicleData(vehicle, value) then
        state:set("vehCreatedApplyProps", nil, true)
        break
      end

      Wait(100)
    end
  end)
end)

lib.callback.register("jg-advancedgarages:client:req-vehicle-and-get-spawn-details", requestVehicleSpawnDetails)
lib.callback.register("jg-advancedgarages:client:on-server-vehicle-created", onServerVehicleCreated)
