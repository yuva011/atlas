local function showPrivateGaragesDashboard()
  if not lib.callback.await("jg-advancedgarages:server:can-create-priv-garage") then
    return false
  end

  local privateGarageData = lib.callback.await("jg-advancedgarages:server:get-all-private-garages")

  SetNuiFocus(true, true)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({
    type = "showPrivGarages",
    garages = privateGarageData.garages,
    allPlayers = privateGarageData.allPlayers,
    locale = Locale,
    config = Config
  })
end

local function createPrivateGarage(data)
  if not lib.callback.await("jg-advancedgarages:server:can-create-priv-garage") then
    return false
  end

  return lib.callback.await("jg-advancedgarages:server:create-private-garage", false, data)
end

local function editPrivateGarage(data)
  if not lib.callback.await("jg-advancedgarages:server:can-create-priv-garage") then
    return false
  end

  return lib.callback.await("jg-advancedgarages:server:edit-private-garage", false, data)
end

local function deletePrivateGarage(data)
  if not lib.callback.await("jg-advancedgarages:server:can-create-priv-garage") then
    return false
  end

  return lib.callback.await("jg-advancedgarages:server:delete-private-garage", false, data)
end

RegisterNUICallback("is-garage-name-available", function(data, cb)
  cb(lib.callback.await("jg-advancedgarages:server:is-garage-name-available", false, data.name))
end)

RegisterNUICallback("create-private-garage", function(data, cb)
  local result = createPrivateGarage(data)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("edit-private-garage", function(data, cb)
  local result = editPrivateGarage(data)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("delete-private-garage", function(data, cb)
  local result = deletePrivateGarage(data)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("get-current-coords", function(_, cb)
  local coords = GetEntityCoords(cache.ped)

  cb({
    x = coords.x,
    y = coords.y,
    z = coords.z,
    h = GetEntityHeading(cache.ped)
  })
end)

RegisterNetEvent("jg-advancedgarages:client:show-private-garages-dashboard", function()
  showPrivateGaragesDashboard()
end)

RegisterNetEvent("jg-advancedgarages:client:show-house-garage", function(garageId, garageType)
  openGarageMenu(garageId, garageType)
end)

RegisterNetEvent("jg-advancedgarages:client:ShowHouseGarage", function(garageId, garageType)
  openGarageMenu(garageId, garageType)
end)

RegisterNetEvent("jg-advancedgarages:client:ShowHouseGarage:qs-housing", function(garageId, garageType)
  openGarageMenu(garageId, garageType)
end)
