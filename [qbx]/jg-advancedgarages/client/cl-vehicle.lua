local liveriesExtrasCam
local liveriesExtrasVehicle
local originalVehicleHeading = 0
local useModLivery = false

local function showVehiclePlateForm()
  if not cache.vehicle then
    Framework.Client.Notify(Locale.notInsideVehicleError, "error")
    return false
  end

  local plate = Framework.Client.GetPlate(cache.vehicle)
  local model = GetEntityArchetypeName(cache.vehicle)
  local vehicleData = lib.callback.await("jg-advancedgarages:server:get-vehicle", false, model, plate)

  if not vehicleData then
    return false
  end

  SetNuiFocus(true, true)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({
    type = "show-vplate-form",
    plate = plate,
    locale = Locale,
    config = Config
  })
end

local function updateVehiclePlate(newPlate)
  newPlate = newPlate:upper()

  if not cache.vehicle then
    Framework.Client.Notify(Locale.notInsideVehicleError, "error")
    return false
  end

  local oldPlate = Framework.Client.GetPlate(cache.vehicle)
  if not oldPlate then
    debugPrint("Framework.Client.GetPlate returned nil.", "warning", "Plate: " .. tostring(oldPlate))
    return false
  end

  local updated = lib.callback.await("jg-advancedgarages:server:vehicle-update-plate", false, oldPlate, newPlate)
  if not updated then
    debugPrint("jg-advancedgarages:server:vehicle-update-plate returned nil.", "warning", oldPlate, newPlate)
    return false
  end

  if GetResourceState("brazzers-fakeplates") == "started" then
    local fakePlate = lib.callback.await("jg-advancedgarages:server:brazzers-get-fakeplate-from-plate", false, oldPlate)
    if fakePlate then
      oldPlate = fakePlate
    end
  end

  Framework.Client.VehicleRemoveKeys(oldPlate, cache.vehicle, "personal")
  setVehiclePlateText(cache.vehicle, newPlate)
  Framework.Client.VehicleGiveKeys(newPlate, cache.vehicle, "personal")

  return true
end

local function closeLiveriesExtrasMenu()
  if not liveriesExtrasVehicle or not DoesEntityExist(liveriesExtrasVehicle) then
    return false
  end

  SetEntityHeading(liveriesExtrasVehicle, originalVehicleHeading)
  SetEntityVisible(liveriesExtrasVehicle, true, false)
  FreezeEntityPosition(liveriesExtrasVehicle, false)

  if liveriesExtrasCam and IsCamActive(liveriesExtrasCam) then
    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(liveriesExtrasCam, false)
    liveriesExtrasCam = nil
  end

  return true
end

local function setVehiclePreviewLivery(livery)
  if not liveriesExtrasVehicle or not DoesEntityExist(liveriesExtrasVehicle) then
    return false
  end

  SetVehicleModKit(liveriesExtrasVehicle, 0)
  if useModLivery then
    local modIndex = tonumber(livery) - 1
    if modIndex < -1 then modIndex = -1 end
    SetVehicleMod(liveriesExtrasVehicle, 48, modIndex, false)
  else
    SetVehicleLivery(liveriesExtrasVehicle, tonumber(livery))
  end

  return true
end

local function setVehiclePreviewExtra(extraId, disabled)
  if not liveriesExtrasVehicle or not DoesEntityExist(liveriesExtrasVehicle) then
    return false
  end

  if not DoesExtraExist(liveriesExtrasVehicle, extraId) then
    Framework.Client.Notify("EXTRA_NOT_AVAILABLE", "error")
    return false
  end

  SetVehicleExtra(liveriesExtrasVehicle, extraId, disabled)
  SetVehicleFixed(liveriesExtrasVehicle)

  return true
end

function showLiveriesExtrasMenu(vehicle)
  liveriesExtrasVehicle = vehicle

  if not liveriesExtrasVehicle or not DoesEntityExist(liveriesExtrasVehicle) then
    return false
  end

  SetVehicleModKit(liveriesExtrasVehicle, 0)
  Wait(100)

  local vehicleCoords = GetEntityCoords(liveriesExtrasVehicle)

  SetEntityVisible(liveriesExtrasVehicle, false, false)
  FreezeEntityPosition(liveriesExtrasVehicle, true)

  originalVehicleHeading = GetEntityHeading(liveriesExtrasVehicle)
  liveriesExtrasCam = CreateCamWithParams(
    "DEFAULT_SCRIPTED_CAMERA",
    vehicleCoords.x - 6,
    vehicleCoords.y,
    vehicleCoords.z + 2,
    0.0,
    0.0,
    270.0,
    0.0,
    false,
    0
  )

  SetCamActive(liveriesExtrasCam, true)
  SetCamFov(liveriesExtrasCam, 60.0)
  PointCamAtCoord(liveriesExtrasCam, vehicleCoords.x, vehicleCoords.y + 1, vehicleCoords.z)
  RenderScriptCams(true, true, 1, true, true)

  local extras = {}
  for extraId = 1, 14 do
    extras[#extras + 1] = {
      id = extraId,
      available = DoesExtraExist(liveriesExtrasVehicle, extraId),
      enabled = IsVehicleExtraTurnedOn(liveriesExtrasVehicle, extraId)
    }
  end

  local liveriesCount = GetVehicleLiveryCount(liveriesExtrasVehicle)
  local currentLivery = GetVehicleLivery(liveriesExtrasVehicle)
  useModLivery = false
  if not liveriesCount or liveriesCount <= 0 then
    local modCount = GetNumVehicleMods(liveriesExtrasVehicle, 48)
    print('^3[Liveries] Old system count: ' .. tostring(liveriesCount) .. ', Mod system count: ' .. tostring(modCount) .. '^0')
    if modCount and modCount > 0 then
      useModLivery = true
      liveriesCount = modCount
      local mod = GetVehicleMod(liveriesExtrasVehicle, 48)
      currentLivery = mod + 1
      print('^2[Liveries] Using mod system, count: ' .. liveriesCount .. ', current: ' .. currentLivery .. '^0')
    end
  else
    print('^2[Liveries] Using old system, count: ' .. liveriesCount .. ', current: ' .. currentLivery .. '^0')
  end

  SetNuiFocus(true, true)
  SendNUIMessage({
    type = "show-liveries-extras-menu",
    extras = extras,
    currentLivery = currentLivery,
    liveriesCount = liveriesCount,
    useModLivery = useModLivery,
    locale = Locale,
    config = Config
  })

  CreateThread(function()
    Wait(500)

    local heading = originalVehicleHeading
    while liveriesExtrasCam and (Config.DoNotSpawnInsideVehicle or cache.vehicle) do
      heading = heading + 0.25
      SetEntityLocallyVisible(liveriesExtrasVehicle)
      SetEntityHeading(liveriesExtrasVehicle, heading)
      Wait(0)
    end

    if not Config.DoNotSpawnInsideVehicle and not cache.vehicle then
      closeLiveriesExtrasMenu()
    end
  end)
end

RegisterNUICallback("change-vehicle-plate", function(data, cb)
  local result = updateVehiclePlate(data.newPlate)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("exit-liveries-extras-menu", function(_, cb)
  local result = closeLiveriesExtrasMenu()

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("toggle-livery", function(data, cb)
  local result = setVehiclePreviewLivery(data.livery_id)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNUICallback("toggle-extra", function(data, cb)
  local result = setVehiclePreviewExtra(data.extra_id, data.disabled)

  if not result then
    return cb({error = true})
  end

  cb(result)
end)

RegisterNetEvent("jg-advancedgarages:client:show-vplate-form", showVehiclePlateForm)
