local INTERIOR_CAMERA_FOV = 40.0
local EXIT_POINT_DISTANCE = 3.0

local cutsceneCams = {}
local previewVehicles = {}
local insideInterior = false
local interiorPoints = {}
local previousCoords
local cameraCutsceneActive = false
local currentGarageType

local function destroyInteriorCams()
  if #cutsceneCams == 0 then
    return
  end

  for _, cam in ipairs(cutsceneCams) do
    DestroyCam(cam, true)
  end

  RenderScriptCams(false, true, 1000, true, true)
  cameraCutsceneActive = false
end

local function playInteriorCameraCutscene()
  if not Config.GarageInteriorCameraCutscene then
    return
  end

  local firstCamCoords = Config.GarageInteriorCameraCutscene[1]
  local secondCamCoords = Config.GarageInteriorCameraCutscene[2]

  local firstCam = CreateCamWithParams(
    "DEFAULT_SCRIPTED_CAMERA",
    firstCamCoords.x,
    firstCamCoords.y,
    firstCamCoords.z,
    0.0,
    0.0,
    firstCamCoords.w,
    INTERIOR_CAMERA_FOV,
    true,
    2
  )

  local secondCam = CreateCamWithParams(
    "DEFAULT_SCRIPTED_CAMERA",
    secondCamCoords.x,
    secondCamCoords.y,
    secondCamCoords.z,
    0.0,
    0.0,
    secondCamCoords.w,
    INTERIOR_CAMERA_FOV,
    true,
    2
  )

  cutsceneCams = {firstCam, secondCam}
  cameraCutsceneActive = true

  SetCamActive(firstCam, true)
  RenderScriptCams(true, false, 0, true, true)
  SetCamActiveWithInterp(secondCam, firstCam, 3000, 0, 0)
  Wait(3000)

  destroyInteriorCams()
end

local function exitInterior(afterExit)
  insideInterior = false
  local garageType = currentGarageType or "personal"
  currentGarageType = nil

  SendNUIMessage({type = "hide"})
  DoScreenFadeOut(500)
  Wait(500)

  for _, vehicleData in ipairs(previewVehicles) do
    if vehicleData.vehicle then
      DeleteEntity(vehicleData.vehicle)
      Framework.Client.VehicleRemoveKeys(vehicleData.plate, vehicleData.vehicle, garageType)
    end
  end

  previewVehicles = {}

  for _, point in ipairs(interiorPoints) do
    point:remove()
  end

  interiorPoints = {}
  Framework.Client.HideTextUI()

  if previousCoords then
    SetEntityCoords(cache.ped, previousCoords.x, previousCoords.y, previousCoords.z, false, false, false, false)
    previousCoords = nil
  end

  lib.callback.await("jg-advancedgarages:server:exit-interior")

  if afterExit then
    afterExit()
  end

  Wait(500)
  DoScreenFadeIn(500)
end

local function createInteriorExitPoints(garageId)
  local exitPoint = lib.points.new({
    coords = Config.GarageInteriorEntrance,
    distance = EXIT_POINT_DISTANCE
  })

  function exitPoint:onEnter()
    if not cache.vehicle then
      Framework.Client.ShowTextUI(Config.ExitInteriorPrompt)
      return
    end

    local vehicle = cache.vehicle
    local model = GetEntityModel(vehicle)
    local plate = Framework.Client.GetPlate(vehicle)

    if not model or not plate then
      return
    end

    CreateThread(function()
      while vehicle == cache.vehicle do
        SetVehicleForwardSpeed(vehicle, 0)
        Wait(0)
      end
    end)

    local spawnerIndex
    for _, previewVehicle in ipairs(previewVehicles) do
      if previewVehicle.vehicle == vehicle then
        spawnerIndex = previewVehicle.spawnerIndex
        break
      end
    end

    exitInterior(function()
      driveVehicleOut(plate, garageId, spawnerIndex)
    end)
  end

  function exitPoint:onExit()
    Framework.Client.HideTextUI()
  end

  function exitPoint:nearby()
    if cameraCutsceneActive and IsControlJustPressed(0, Config.ExitInteriorKeyBind) then
      destroyInteriorCams()
    end

    if not cache.vehicle and IsControlJustPressed(0, Config.ExitInteriorKeyBind) and not cameraCutsceneActive then
      exitInterior()
    end
  end

  interiorPoints[#interiorPoints + 1] = exitPoint

  local markerPoint = lib.points.new({
    coords = Config.GarageInteriorEntrance,
    distance = 20.0
  })

  function markerPoint:nearby()
    drawMarkerOnFrame(Config.GarageInteriorEntrance, {
      id = 21,
      size = {
        x = 0.3,
        y = 0.3,
        z = 0.3
      },
      color = {
        r = 255,
        g = 255,
        b = 255,
        a = 120
      },
      bobUpAndDown = 0,
      faceCamera = 0,
      rotate = 1,
      drawOnEnts = 0
    })
  end

  interiorPoints[#interiorPoints + 1] = markerPoint
end

local function startInteriorVehicleAccessThread()
  CreateThread(function()
    while insideInterior do
      local waitMs = 500
      local vehicle = GetVehiclePedIsTryingToEnter(cache.ped)

      if vehicle ~= 0 then
        waitMs = 0
        SetVehicleEngineOn(vehicle, true, true, true)
        SetVehicleNeedsToBeHotwired(vehicle, false)
        SetVehicleDoorsLocked(vehicle, 1)
        EnableControlAction(0, 23, true)
      end

      Wait(waitMs)
    end
  end)
end

local function setPreviewVehicleProperties(vehicle, props)
  if type(props) ~= "table" then
    return
  end

  if Config.Framework == "QBCore" and QBCore then
    QBCore.Functions.SetVehicleProperties(vehicle, props)
  elseif Config.Framework == "ESX" and ESX then
    ESX.Game.SetVehicleProperties(vehicle, props)
  else
    lib.setVehicleProperties(vehicle, props)
  end
end

local function enterInterior(garageId, vehicles)
  insideInterior = true

  local garage = getAvailableGarageLocations()[garageId]
  if not garage then
    garage = {
      garageType = "personal",
      checkVehicleGarageId = Config.GarageUniqueLocations,
      enableInteriors = Config.PrivGarageEnableInteriors
    }
  end

  currentGarageType = garage.garageType

  local interiorVehicles = {}
  for _, vehicle in ipairs(vehicles) do
    if IsModelInCdimage(vehicle.hash) then
      local validGarage = not garage.checkVehicleGarageId or vehicle.garageId == garageId

      if validGarage and not vehicle.impound and vehicle.inGarage and not vehicle.isSpawned then
        interiorVehicles[#interiorVehicles + 1] = vehicle
      end
    end
  end

  if #interiorVehicles == 0 then
    Framework.Client.Notify(Locale.noVehiclesAvailableToDrive, "error")
    exitInterior()
    return
  end

  CreateThread(function()
    DoScreenFadeOut(500)
    Wait(500)

    for index, coords in ipairs(Config.GarageInteriorVehiclePositions) do
      local vehicleData = interiorVehicles[index]
      if not vehicleData then
        break
      end

      local vehicle = createClientVehicle(vehicleData.hash, coords, vehicleData.plate, true)

      setPreviewVehicleProperties(vehicle, vehicleData.props)

      previewVehicles[#previewVehicles + 1] = {
        vehicle = vehicle,
        spawnerIndex = vehicleData.spawnerIndex,
        plate = vehicleData.plate
      }
    end

    previousCoords = GetEntityCoords(cache.ped)
    SetEntityCoords(cache.ped, Config.GarageInteriorEntrance.x, Config.GarageInteriorEntrance.y, Config.GarageInteriorEntrance.z, false, false, false, false)
    SetEntityHeading(cache.ped, Config.GarageInteriorEntrance.w)

    createInteriorExitPoints(garageId)
    DoScreenFadeIn(500)
    playInteriorCameraCutscene()
    startInteriorVehicleAccessThread()
  end)
end

lib.onCache("vehicle", function(vehicle)
  if not insideInterior then
    return
  end

  if not vehicle or vehicle == 0 then
    SendNUIMessage({type = "hide"})
    return
  end

  local plate = Framework.Client.GetPlate(vehicle)
  if not plate then
    return
  end

  local model = GetEntityArchetypeName(vehicle)
  local vehicleData = lib.callback.await("jg-advancedgarages:server:get-vehicle", false, model, plate)

  if not vehicleData then
    return false
  end

  vehicleData.model = type(vehicleData.model) == "string" and vehicleData.model or getModelNameFromHash(vehicleData.hash)
  vehicleData.vehicleLabel = Framework.Client.GetVehicleLabel(vehicleData.model)

  SendNUIMessage({
    type = "show-interior-vehicle",
    vehicle = vehicleData,
    config = Config,
    locale = Locale
  })
end)

RegisterNetEvent("jg-advancedgarages:client:enter-interior", enterInterior)
