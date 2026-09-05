local function notify(source, message, messageType)
  Framework.Server.Notify(source, message, messageType)
end

local function isAdmin(source)
  if Framework.Server.IsAdmin(source) then
    return true
  end

  notify(source, "INSUFFICIENT_PERMISSIONS", "error")
  return false
end

local function getCurrentOwnedVehicle(source)
  local vehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)

  if not vehicle or vehicle == 0 then
    notify(source, Locale.notInsideVehicleError, "error")
    return nil
  end

  local plate = Framework.Server.GetPlate(vehicle)

  if not plate then
    debugPrint("Framework.Server.GetPlate returned nil.", "warning")
    return nil
  end

  local vehicleData = getVehicleData(source, false, plate)

  if not vehicleData then
    notify(source, Locale.vehicleNotOwnedByPlayerError, "error")
    return nil
  end

  return vehicle, plate, vehicleData
end

local function getSocieties(societyType)
  if societyType == "gang" then
    return Framework.Server.GetGangs() or {}
  end

  return Framework.Server.GetJobs() or {}
end

local function setSocietyVehicle(source, societyType, societyName, minGrade)
  local societies = getSocieties(societyType)
  local _, plate = getCurrentOwnedVehicle(source)

  if not plate then
    return
  end

  if not societyName or not societies[societyName] then
    local errorMessage = societyType == "job" and Locale.invalidJobError or Locale.invalidGangError
    notify(source, errorMessage, "error")
    return
  end

  local query = societyType == "gang" and Framework.Queries.SetGangVehicle or Framework.Queries.SetJobVehicle

  MySQL.update.await(query:format(Framework.VehiclesTable, Framework.PlayerIdentifier), {
    societyName,
    minGrade,
    plate
  })

  local successMessage = societyType == "gang" and Locale.vehicleAddedToGangGarageSuccess or Locale.vehicleAddedToJobGarageSuccess
  notify(source, successMessage:gsub("%%{value}", societyName), "success")
end

local function transferSocietyVehicleToPlayer(source, targetPlayerId)
  local _, plate = getCurrentOwnedVehicle(source)

  if not plate then
    return
  end

  local targetIdentifier = Framework.Server.GetPlayerIdentifier(targetPlayerId)

  if not targetIdentifier then
    notify(source, Locale.playerNotOnlineError, "error")
    return
  end

  MySQL.update.await(
    Framework.Queries.SetSocietyVehicleAsPlayerOwned:format(Framework.VehiclesTable, Framework.PlayerIdentifier),
    {targetIdentifier, plate}
  )

  local targetInfo = Framework.Server.GetPlayerInfo(targetPlayerId)
  local targetName = targetInfo and targetInfo.name or tostring(targetPlayerId)

  notify(source, Locale.vehicleTransferSuccess:gsub("%%{value}", targetName), "success")
  notify(targetPlayerId, Locale.vehicleReceived:gsub("%%{value}", plate), "success")
end

lib.addCommand(Config.JobGarageSetVehicleCommand, {
  help = Locale.cmdSetJobVehicle,
  params = {
    {
      name = "job",
      type = "string",
      help = Locale.cmdArgJobName
    },
    {
      name = "grade",
      type = "number",
      help = Locale.cmgArgMinJobRank,
      optional = true
    }
  }
}, function(source, args)
  if not isAdmin(source) then
    return
  end

  setSocietyVehicle(source, "job", args.job, args.grade or 0)
end)

lib.addCommand(Config.GangGarageSetVehicleCommand, {
  help = Locale.cmdSetGangVehicle,
  params = {
    {
      name = "gang",
      type = "string",
      help = Locale.cmdArgGangName
    },
    {
      name = "grade",
      type = "number",
      help = Locale.cmgArgMinGangRank,
      optional = true
    }
  }
}, function(source, args)
  if not isAdmin(source) then
    return
  end

  local hasSupportedGangFramework = Config.Framework == "QBCore"
    or Config.Framework == "Qbox"
    or Config.Gangs == "rcore_gangs"
    or Config.GangEnableCustomESXIntegration

  if not hasSupportedGangFramework then
    notify(source, "Gangs are only compatible with QBCore & Qbox", "error")
    return
  end

  setSocietyVehicle(source, "gang", args.gang, args.grade or 0)
end)

lib.addCommand(Config.JobGarageRemoveVehicleCommand, {
  help = Locale.cmdRemoveJobVehicle,
  params = {
    {
      name = "id",
      type = "playerId",
      help = Locale.cmdArgPlayerId
    }
  }
}, function(source, args)
  if not isAdmin(source) then
    return
  end

  transferSocietyVehicleToPlayer(source, tonumber(args.id) or 0)
end)

lib.addCommand(Config.GangGarageRemoveVehicleCommand, {
  help = Locale.cmdRemoveGangVehicle,
  params = {
    {
      name = "id",
      type = "playerId",
      help = Locale.cmdArgPlayerId
    }
  }
}, function(source, args)
  if not isAdmin(source) then
    return
  end

  transferSocietyVehicleToPlayer(source, tonumber(args.id) or 0)
end)
