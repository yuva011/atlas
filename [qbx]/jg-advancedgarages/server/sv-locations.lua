local function getPlayerPrivateGarages(playerSource)
  local playerIdentifier = Framework.Server.GetPlayerIdentifier(playerSource)

  if not playerIdentifier then
    return {}
  end

  return MySQL.query.await(Framework.Queries.GetPrivateGarages, {"%" .. playerIdentifier .. "%"}) or {}
end

local function matchesMember(value, name)
  if type(value) == "table" then
    return isItemInList(value, name)
  end

  return value == name
end

local function enableInteriorForVehicleType(vehicleType, enabled)
  return vehicleType == "car" and enabled
end

local function addPersonalGarage(garages, garageId, garage)
  garages[garageId] = lib.table.deepclone(garage)
  garages[garageId].checkVehicleGarageId = Config.GarageUniqueLocations
  garages[garageId].enableInteriors = enableInteriorForVehicleType(garage.type, Config.GarageEnableInteriors)
  garages[garageId].uniqueBlips = Config.GarageUniqueBlips
  garages[garageId].infiniteSpawns = Config.AllowInfiniteVehicleSpawns
  garages[garageId].garageType = "personal"
end

local function addPrivateGarage(garages, garage)
  garages[garage.name] = {
    coords = vector3(garage.x, garage.y, garage.z),
    spawn = vector4(garage.x, garage.y, garage.z, garage.h),
    distance = garage.distance,
    type = garage.type,
    hideBlip = Config.PrivGarageHideBlips,
    blip = Config.PrivGarageBlip,
    uniqueBlips = Config.GarageUniqueBlips,
    checkVehicleGarageId = Config.GarageUniqueLocations,
    enableInteriors = enableInteriorForVehicleType(garage.type, Config.PrivGarageEnableInteriors),
    infiniteSpawns = Config.AllowInfiniteVehicleSpawns,
    garageType = "personal"
  }
end

local function addJobGarage(garages, garageId, garage)
  garages[garageId] = lib.table.deepclone(garage)
  garages[garageId].checkVehicleGarageId = Config.JobGarageUniqueLocations and garage.vehiclesType ~= "spawner"
  garages[garageId].enableInteriors = enableInteriorForVehicleType(garage.type, Config.JobGarageEnableInteriors)
  garages[garageId].uniqueBlips = Config.JobGarageUniqueBlips
  garages[garageId].infiniteSpawns = Config.JobGaragesAllowInfiniteVehicleSpawns
  garages[garageId].garageType = "job"
end

local function addGangGarage(garages, garageId, garage)
  garages[garageId] = lib.table.deepclone(garage)
  garages[garageId].checkVehicleGarageId = Config.GangGarageUniqueLocations and garage.vehiclesType ~= "spawner"
  garages[garageId].enableInteriors = enableInteriorForVehicleType(garage.type, Config.GangGarageEnableInteriors)
  garages[garageId].uniqueBlips = Config.GangGarageUniqueBlips
  garages[garageId].infiniteSpawns = Config.GangGaragesAllowInfiniteVehicleSpawns
  garages[garageId].garageType = "gang"
end

local function addImpound(garages, impoundId, impound, playerJob)
  garages[impoundId] = lib.table.deepclone(impound)
  garages[impoundId].uniqueBlips = Config.ImpoundUniqueBlips
  garages[impoundId].garageType = "impound"
  garages[impoundId].hasImpoundJob = playerJob and matchesMember(impound.job, playerJob.name)
end

function getPlayerAvailableGarageLocations(playerSource)
  local garages = {}

  for garageId, garage in pairs(Config.GarageLocations) do
    addPersonalGarage(garages, garageId, garage)
  end

  for _, privateGarage in ipairs(getPlayerPrivateGarages(playerSource)) do
    addPrivateGarage(garages, privateGarage)
  end

  local playerJob = Framework.Server.GetPlayerJob(playerSource)
  for garageId, garage in pairs(Config.JobGarageLocations) do
    if playerJob and matchesMember(garage.job, playerJob.name) then
      addJobGarage(garages, garageId, garage)
    end
  end

  local gangIntegrationEnabled = Config.Framework == "QBCore"
    or Config.Framework == "Qbox"
    or Config.GangEnableCustomESXIntegration
    or Config.Gangs == "rcore_gangs"

  local playerGang
  if gangIntegrationEnabled then
    playerGang = Framework.Server.GetPlayerGang(playerSource)
  end

  for garageId, garage in pairs(Config.GangGarageLocations) do
    if playerGang and matchesMember(garage.gang, playerGang.name) then
      addGangGarage(garages, garageId, garage)
    end
  end

  for impoundId, impound in pairs(Config.ImpoundLocations) do
    addImpound(garages, impoundId, impound, playerJob)
  end

  return garages
end

lib.callback.register("jg-advancedgarages:server:get-available-garage-locations", getPlayerAvailableGarageLocations)
