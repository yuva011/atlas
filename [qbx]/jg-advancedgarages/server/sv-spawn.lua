local spawnAttempts = {}
local TELEPORT_DISTANCE = 10.0
local MAX_PROP_APPLY_ATTEMPTS = 3

local function createServerSetterVehicle(playerSource, modelHash, vehicleType, plate, spawnCoords, warpIntoVehicle, vehicleData)
  if spawnAttempts[playerSource] and spawnAttempts[playerSource] == MAX_PROP_APPLY_ATTEMPTS then
    print("^3[WARNING] Vehicle props failed to set after trying several times. First check if the plate within the vehicle props JSON does not match the plate column. If they match, and you see this message regularly, try setting Config.SpawnVehiclesWithServerSetter = false")
    spawnAttempts[playerSource] = 0
    return false
  end

  spawnAttempts[playerSource] = (spawnAttempts[playerSource] or 0) + 1

  local vehicle = CreateVehicleServerSetter(modelHash, vehicleType, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w)

  lib.waitFor(function()
    return DoesEntityExist(vehicle) or nil
  end, "Timed out while trying to spawn in vehicle (server)", 10000)

  lib.waitFor(function()
    return GetVehicleNumberPlateText(vehicle) ~= "" or nil
  end, "Vehicle number plate text is nil", 5000)

  SetEntityRoutingBucket(vehicle, GetPlayerRoutingBucket(playerSource))

  if SetEntityOrphanMode then
    SetEntityOrphanMode(vehicle, 2)
  end

  for seat = -1, 6 do
    local ped = GetPedInVehicleSeat(vehicle, seat)
    if ped ~= 0 then
      DeleteEntity(ped)
    end
  end

  if warpIntoVehicle then
    local playerPed = GetPlayerPed(playerSource)

    pcall(function()
      lib.waitFor(function()
        if GetPedInVehicleSeat(vehicle, -1) == playerPed then
          return true
        end

        SetPedIntoVehicle(playerPed, vehicle, -1)
      end, nil, 1000)
    end)
  end

  lib.waitFor(function()
    return NetworkGetEntityOwner(vehicle) ~= -1 or nil
  end, "Timed out waiting for server-setter entity to have an owner (owner is -1)", 5000)

  local state = Entity(vehicle).state
  state:set("vehInit", true, true)

  if type(vehicleData) == "table" then
    state:set("vehCreatedApplyProps", vehicleData, true)
  end

  local propsApplied = pcall(function()
    lib.waitFor(function()
      local pendingProps = Entity(vehicle).state.vehCreatedApplyProps
      if pendingProps then
        return nil
      end

      if plate and plate ~= "" and Framework.Server.GetPlate(vehicle) ~= plate then
        return nil
      end

      return true
    end, nil, 2000)
  end)

  if not propsApplied then
    DeleteEntity(vehicle)
    deleteVehicle(vehicle)
    return createServerSetterVehicle(playerSource, modelHash, vehicleType, plate, spawnCoords, warpIntoVehicle, vehicleData)
  end

  spawnAttempts[playerSource] = 0
  return NetworkGetNetworkIdFromEntity(vehicle)
end

function spawnVehicleServer(playerSource, vehicleId, model, plate, spawnCoords, warpIntoVehicle, vehicleData, keyType)
  local modelHash, vehicleType, hasSeats = lib.callback.await(
    "jg-advancedgarages:client:req-vehicle-and-get-spawn-details",
    playerSource,
    model
  )

  if not modelHash then
    return false
  end

  local playerPed = GetPlayerPed(playerSource)
  local playerCoords = GetEntityCoords(playerPed)
  local teleportedFrom = false

  if #(playerCoords - spawnCoords.xyz) > TELEPORT_DISTANCE then
    SetEntityCoords(playerPed, spawnCoords.x + 3.0, spawnCoords.y + 3.0, spawnCoords.z, false, false, false, false)
    teleportedFrom = playerCoords
  end

  local shouldWarp = hasSeats and warpIntoVehicle or nil
  local netId = createServerSetterVehicle(playerSource, modelHash, vehicleType, plate, spawnCoords, shouldWarp, vehicleData)

  if not netId then
    return false
  end

  local clientResult = lib.callback.await(
    "jg-advancedgarages:client:on-server-vehicle-created",
    playerSource,
    netId,
    teleportedFrom,
    shouldWarp,
    modelHash,
    vehicleId,
    plate,
    vehicleData,
    keyType
  )

  if not clientResult then
    if NetworkDoesEntityExistWithNetworkId(netId) then
      DeleteEntity(NetworkGetEntityFromNetworkId(netId))
      debugPrint("Failed to create vehicle, deleted entity.", "warning", netId)
    end

    return false
  end

  return netId, clientResult
end
