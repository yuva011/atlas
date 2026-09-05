function doesVehicleNeedServicing(vehicleData)
  if not vehicleData then
    return false
  end

  if GetResourceState("jg-mechanic") ~= "started" then
    return false
  end

  if not Globals.MechanicConfig then
    local ok = pcall(function()
      Globals.MechanicConfig = exports["jg-mechanic"]:config()
    end)

    if not ok then
      print("^3[WARNING] You are running jg-mechanic, but you need to be using v1.0.10 or newer to use it with Advanced Garages v3. Some functionality may not work as expected.")
    end
  end

  if not Globals.MechanicConfig or not Globals.MechanicConfig.EnableVehicleServicing then
    return false
  end

  if type(vehicleData.servicingData) ~= "table" then
    return false
  end

  for _, serviceValue in pairs(vehicleData.servicingData) do
    if serviceValue <= Globals.MechanicConfig.ServiceRequiredThreshold then
      return true
    end
  end

  return false
end

function isVehicleTransferBlacklisted(model)
  if not Config.PlayerTransferBlacklist then
    return false
  end

  local modelHash = convertModelToHash(model)

  for _, blacklistedModel in pairs(Config.PlayerTransferBlacklist) do
    if modelHash == joaat(blacklistedModel) then
      return true
    end
  end

  return false
end

function isVehicleSpawned(plate)
  if not plate or plate == "" then
    return false
  end

  if GetResourceState("AdvancedParking") == "started" and exports.AdvancedParking:GetVehiclePosition(plate) then
    return true
  end

  local netId = Globals.OutsideVehicles[plate]
  if not netId then
    return false
  end

  local vehicle = NetworkGetEntityFromNetworkId(netId)
  return DoesEntityExist(vehicle) and GetVehicleEngineHealth(vehicle) > -3999
end

local function deleteOutsideVehicle(plate)
  local netId = Globals.OutsideVehicles[plate]
  if not netId then
    return
  end

  deleteVehicle(NetworkGetEntityFromNetworkId(netId), netId, plate)
end

exports("deleteOutsideVehicle", deleteOutsideVehicle)

local function registerVehicleOutside(plate, netId)
  Globals.OutsideVehicles[plate] = netId
end

exports("registerVehicleOutside", registerVehicleOutside)

local function updateVehiclePlate(playerSource, oldPlate, newPlate)
  local vehicle = GetVehiclePedIsIn(GetPlayerPed(playerSource), false)

  if not vehicle then
    Framework.Server.Notify(playerSource, Locale.notInsideVehicleError, "error")
    return false
  end

  local currentPlate = Framework.Server.GetPlate(vehicle)
  if currentPlate ~= oldPlate then
    debugPrint("Framework.Server.GetPlate does not match with original plate", "warning", currentPlate, oldPlate)
    return false
  end

  local plateExists = MySQL.scalar.await(Framework.Queries.GetVehiclePlateOnly:format(Framework.VehiclesTable), {newPlate})
  if plateExists then
    Framework.Server.Notify(playerSource, Locale.vehiclePlateExistsError, "error")
    return false
  end

  local vehicleData = getVehicleData(playerSource, false, oldPlate)
  if not vehicleData then
    print("^1Error: could not get vehicle data before plate change")
    return false
  end

  local propsJson = vehicleData[Framework.VehProps]
  local props = propsJson and json.decode(propsJson) or nil

  if not props then
    print("^1Error: could not get props before plate change")
    return false
  end

  props.plate = newPlate

  MySQL.update.await(
    Framework.Queries.UpdateVehiclePlate:format(Framework.VehiclesTable, Framework.VehProps),
    {newPlate, json.encode(props), oldPlate}
  )

  if GetResourceState("jg-mechanic") == "started" then
    local ok = pcall(function()
      exports["jg-mechanic"]:vehiclePlateUpdated(oldPlate, newPlate)
    end)

    if not ok then
      print("^1[WARNING] Update jg-mechanic to v1.0.11 or newer as it needs to update internal data to the updated plate!")
    end
  end

  Framework.Server.Notify(playerSource, Locale.vehiclePlateUpdateSuccess:gsub("%%{value}", newPlate), "success")
  return true
end

local function deleteVehicleFromDatabase(playerSource)
  local vehicle = GetVehiclePedIsIn(GetPlayerPed(playerSource), false)

  if not vehicle then
    Framework.Server.Notify(playerSource, Locale.notInsideVehicleError, "error")
    return
  end

  local plate = Framework.Server.GetPlate(vehicle)
  if not plate then
    return
  end

  local vehicleData = getVehicleData(playerSource, false, plate)
  if not vehicleData then
    Framework.Server.Notify(playerSource, Locale.vehicleNotOwnedByPlayerError, "error")
    return
  end

  MySQL.query.await(Framework.Queries.DeleteVehicle:format(Framework.VehiclesTable), {plate})
  deleteVehicle(vehicle)
  Framework.Server.Notify(playerSource, Locale.vehicleDeletedSuccess:gsub("%%{value}", plate), "success")
end

local function returnVehicleToGarage(playerSource, plate)
  plate = plate:upper()

  if not plate or not getVehicleData(playerSource, false, plate) then
    Framework.Server.Notify(playerSource, Locale.vehicleNotOwnedByPlayerError, "error")
    return false
  end

  local netId = Globals.OutsideVehicles[plate]
  if not netId then
    Framework.Server.Notify(playerSource, Locale.vehicleParkedSuccess, "error")
    return true
  end

  deleteVehicle(NetworkGetEntityFromNetworkId(netId))
  Globals.OutsideVehicles[plate] = nil

  MySQL.update.await(Framework.Queries.SetInGarage:format(Framework.VehiclesTable), {plate})
  Framework.Server.Notify(playerSource, Locale.vehicleImpoundReturnedToOwnerSuccess, "success")
end

RegisterNetEvent("jg-advancedgarages:server:register-vehicle-outside", registerVehicleOutside)
RegisterNetEvent("jg-advancedgarages:server:RegisterVehicleOutside", registerVehicleOutside)

lib.callback.register("jg-advancedgarages:server:vehicle-update-plate", function(playerSource, oldPlate, newPlate)
  if not Framework.Server.IsAdmin(playerSource) then
    debugPrint("Framework.Server.IsAdmin", "warning", "Returned false")
    return false
  end

  return updateVehiclePlate(playerSource, oldPlate, newPlate)
end)

lib.addCommand(Config.ChangeVehiclePlate or "vplate", false, function(playerSource)
  if not Framework.Server.IsAdmin(playerSource) then
    return Framework.Server.Notify(playerSource, "INSUFFICIENT_PERMISSIONS", "error")
  end

  TriggerClientEvent("jg-advancedgarages:client:show-vplate-form", playerSource)
end)

lib.addCommand(Config.DeleteVehicleFromDB or "dvdb", {
  help = Locale.cmdDeleteVeh
}, function(playerSource)
  if not Framework.Server.IsAdmin(playerSource) then
    return Framework.Server.Notify(playerSource, "INSUFFICIENT_PERMISSIONS", "error")
  end

  deleteVehicleFromDatabase(playerSource)
end)

lib.addCommand(Config.ReturnVehicleToGarage or "vreturn", {
  help = "Return vehicle back to garage (admin only)",
  params = {}
}, function(playerSource, args)
  if not Framework.Server.IsAdmin(playerSource) then
    return Framework.Server.Notify(playerSource, "INSUFFICIENT_PERMISSIONS", "error")
  end

  returnVehicleToGarage(playerSource, table.concat(args, " "))
end)

if Config.Framework == "Qbox" and GetConvar("qbx:enableVehiclePersistence", "false") == "true" then
  AddStateBagChangeHandler("vehicleid", "", function(bagName, _, vehicleId)
    if not vehicleId or vehicleId == 0 then
      return
    end

    local vehicle = GetEntityFromStateBagName(bagName)
    if vehicle == 0 then
      return
    end

    local plate = Framework.Server.GetPlate(vehicle)
    if not plate then
      return
    end

    if not Globals.OutsideVehicles[plate] then
      return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    Globals.OutsideVehicles[plate] = netId
    lib.print.info("[Qbox Persistence Tracker] vehicle", vehicleId, "updated to netId", netId)
  end)
end
