local function isGarageNameAvailable(playerSource, garageName)
  local garageNames = tableKeys(getAllGaragesAndImpounds())

  if lib.table.contains(garageNames, garageName) then
    Framework.Server.Notify(playerSource, "GARAGE_NAME_TAKEN", "error")
    print("^1[ERROR] Garage name has already been taken. Every garage name, including public, job, gang in the config have to be uniquely named")
    return false
  end

  return true
end

local function canCreatePrivateGarage(playerSource)
  local playerJob = Framework.Server.GetPlayerJob(playerSource)

  if not playerJob then
    return false
  end

  local allowedByJob = Config.PrivGarageCreateJobRestriction
    and isItemInList(Config.PrivGarageCreateJobRestriction, playerJob.name)

  if not allowedByJob and not Framework.Server.IsAdmin(playerSource) then
    Framework.Server.Notify(playerSource, Locale.actionNotAllowedError, "error")
    return false
  end

  return true
end

local function refreshOwnersBlips(owners)
  for _, owner in pairs(owners) do
    local ownerSource = Framework.Server.GetSrcFromIdentifier(owner.identifier)
    if ownerSource then
      TriggerClientEvent("jg-advancedgarages:client:update-blips-text-uis", ownerSource)
    end
  end
end

local function formatGarageLocation(data)
  return table.concat({
    math.ceil(data.x),
    math.ceil(data.y),
    math.ceil(data.z),
    math.ceil(data.h)
  }, ", ") .. " / dist: " .. data.distance
end

local function privateGarageWebhookFields(data)
  return {
    {
      key = "Name",
      value = data.name
    },
    {
      key = "Type",
      value = data.type
    },
    {
      key = "Owners",
      value = json.encode(data.owners)
    },
    {
      key = "Location",
      value = formatGarageLocation(data)
    }
  }
end

lib.callback.register("jg-advancedgarages:server:is-garage-name-available", isGarageNameAvailable)
lib.callback.register("jg-advancedgarages:server:can-create-priv-garage", canCreatePrivateGarage)

lib.callback.register("jg-advancedgarages:server:create-private-garage", function(playerSource, data)
  if not canCreatePrivateGarage(playerSource) then
    return false
  end

  if not isGarageNameAvailable(playerSource, data.name) then
    return false
  end

  local garageId = MySQL.insert.await(
    "INSERT INTO player_priv_garages SET owners = ?, name = ?, type = ?, x = ?, y = ?, z = ?, h = ?, distance = ?",
    {json.encode(data.owners), data.name, data.type, data.x, data.y, data.z, data.h, data.distance}
  )

  refreshOwnersBlips(data.owners)
  Framework.Server.Notify(playerSource, Locale.garageCreatedSuccess, "success")
  sendWebhook(playerSource, Webhooks.PrivateGarages, "Private Garage Created", "success", privateGarageWebhookFields(data))

  return {
    id = garageId
  }
end)

lib.callback.register("jg-advancedgarages:server:edit-private-garage", function(playerSource, data)
  if not canCreatePrivateGarage(playerSource) then
    return false
  end

  local oldGarage = MySQL.single.await("SELECT * FROM player_priv_garages WHERE id = ?", {data.id})
  if not oldGarage then
    return false
  end

  MySQL.update.await(
    "UPDATE player_priv_garages SET owners = ?, type = ?, x = ?, y = ?, z = ?, h = ?, distance = ? WHERE id = ?",
    {json.encode(data.owners), data.type, data.x, data.y, data.z, data.h, data.distance, data.id}
  )

  refreshOwnersBlips(lib.table.merge(json.decode(oldGarage.owners), data.owners))
  Framework.Server.Notify(playerSource, Locale.garageUpdatedSuccess, "success")
  sendWebhook(playerSource, Webhooks.PrivateGarages, "Private Garage Edited", "warn", privateGarageWebhookFields(data))

  return true
end)

lib.callback.register("jg-advancedgarages:server:delete-private-garage", function(playerSource, data)
  if not canCreatePrivateGarage(playerSource) then
    return false
  end

  MySQL.update.await("DELETE FROM player_priv_garages WHERE id = ?", {data.id})
  refreshOwnersBlips(data.owners)
  sendWebhook(playerSource, Webhooks.PrivateGarages, "Private Garage Deleted", "danger", {
    {
      key = "Name",
      value = data.name
    }
  })

  return true
end)

lib.callback.register("jg-advancedgarages:server:get-all-private-garages", function(playerSource)
  if not canCreatePrivateGarage(playerSource) then
    return false
  end

  return {
    garages = MySQL.query.await("SELECT * FROM player_priv_garages ORDER BY id DESC"),
    allPlayers = Framework.Server.GetPlayers()
  }
end)

lib.addCommand(Config.PrivGarageCreateCommand, false, function(playerSource)
  if not canCreatePrivateGarage(playerSource) then
    return
  end

  TriggerClientEvent("jg-advancedgarages:client:show-private-garages-dashboard", playerSource)
end)
