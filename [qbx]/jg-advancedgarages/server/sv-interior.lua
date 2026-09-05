local interiorPlayers = {}

lib.callback.register("jg-advancedgarages:server:enter-interior", function(playerSource, garageId, vehicles)
  local playerIdentifier = Framework.Server.GetPlayerIdentifier(playerSource)

  if not playerIdentifier then
    return false
  end

  local originalBucket = 0
  if Config.ReturnToPreviousRoutingBucket then
    originalBucket = GetPlayerRoutingBucket(playerSource)
  end

  local interiorBucket = math.random(100, 999)
  SetPlayerRoutingBucket(playerSource, interiorBucket)

  interiorPlayers[playerIdentifier] = {
    garage = garageId,
    originalBucket = originalBucket,
    currentBucket = interiorBucket
  }

  TriggerClientEvent("jg-advancedgarages:client:enter-interior", playerSource, garageId, vehicles)
  return true
end)

lib.callback.register("jg-advancedgarages:server:exit-interior", function(playerSource)
  local playerIdentifier = Framework.Server.GetPlayerIdentifier(playerSource)

  if not playerIdentifier then
    return false
  end

  local interiorData = interiorPlayers[playerIdentifier]
  if interiorData and Config.ReturnToPreviousRoutingBucket then
    SetPlayerRoutingBucket(playerSource, interiorData.originalBucket)
  else
    SetPlayerRoutingBucket(playerSource, 0)
  end

  interiorPlayers[playerIdentifier] = nil
  return true
end)
