function findVehicleSpawnCoords(coords)
  if type(coords) == "table" then
    for _, spawnCoords in pairs(coords) do
      if not lib.getClosestVehicle(spawnCoords.xyz, 2.5) then
        return spawnCoords
      end
    end

    return findVehicleSpawnCoords(coords[1])
  end

  local spawnCoords = coords

  for _ = 1, 10 do
    if not lib.getClosestVehicle(spawnCoords.xyz, 2.5) then
      return spawnCoords
    end

    local x = spawnCoords.x
    local y = spawnCoords.y
    local heading = spawnCoords.w

    if (heading >= 0 and heading <= 45) or (heading >= 315 and heading <= 360) then
      y = y + 5
    elseif heading >= 46 and heading <= 135 then
      x = x - 5
    elseif heading >= 136 and heading <= 225 then
      y = y - 5
    elseif heading >= 226 and heading <= 314 then
      x = x + 5
    end

    spawnCoords = vector4(x, y, spawnCoords.z, heading)
  end

  return spawnCoords
end

function deleteVehicle(vehicle, netId, plate)
  if GetResourceState("AdvancedParking") == "started" then
    if netId or plate then
      exports.AdvancedParking:DeleteVehicleUsingData(nil, netId, plate, false)
    else
      exports.AdvancedParking:DeleteVehicle(vehicle, false)
    end
  else
    DeleteEntity(vehicle)
  end
end

function getNearbyPlayers(playerSource, coords, radius, includeSource)
  local nearbyPlayers = lib.getNearbyPlayers(coords, radius)
  local players = {}

  for _, nearbyPlayer in ipairs(nearbyPlayers) do
    if includeSource or nearbyPlayer.id ~= playerSource then
      local playerInfo = Framework.Server.GetPlayerInfo(nearbyPlayer.id)

      players[#players + 1] = {
        id = nearbyPlayer.id,
        identifier = Framework.Server.GetPlayerIdentifier(nearbyPlayer.id),
        name = playerInfo and playerInfo.name
      }
    end
  end

  return players
end

function getAllGaragesAndImpounds()
  local garages = lib.table.deepclone(Config.GarageLocations)
  local jobGarages = lib.table.deepclone(Config.JobGarageLocations)
  local gangGarages = lib.table.deepclone(Config.GangGarageLocations)
  local impounds = lib.table.deepclone(Config.ImpoundLocations)
  local privateGarages = {}

  local rows = MySQL.query.await("SELECT * FROM player_priv_garages")
  for _, row in ipairs(rows) do
    privateGarages[row.name] = {
      coords = vector3(row.x, row.y, row.z),
      spawn = vector4(row.x, row.y, row.z, row.h),
      distance = row.distance,
      type = row.type,
      hideBlip = Config.PrivGarageHideBlips,
      blip = Config.PrivGarageBlip
    }
  end

  return lib.table.merge(
    lib.table.merge(
      lib.table.merge(
        lib.table.merge(impounds, privateGarages),
        gangGarages
      ),
      jobGarages
    ),
    garages
  ) or {}
end

lib.callback.register("jg-advancedgarages:server:nearby-players", function(playerSource, coords, radius, includeSource)
  return getNearbyPlayers(playerSource, coords, radius, includeSource)
end)

AddEventHandler("onResourceStart", function(resourceName)
  if GetCurrentResourceName() ~= resourceName then
    return
  end

  initSQL()
end)
