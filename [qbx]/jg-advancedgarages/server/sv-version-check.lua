local RESOURCE_NAME = "jg-advancedgarages"
local VERSION_URL = "https://raw.githubusercontent.com/jgscripts/versions/main/" .. RESOURCE_NAME .. ".txt"

local function parseVersion(version)
  local parts = {}

  for part in version:gmatch("[^.]+") do
    parts[#parts + 1] = tonumber(part)
  end

  return parts
end

local function isVersionNewer(currentVersion, latestVersion)
  local currentParts = parseVersion(currentVersion)
  local latestParts = parseVersion(latestVersion)

  for index = 1, math.max(#currentParts, #latestParts) do
    local currentPart = currentParts[index] or 0
    local latestPart = latestParts[index] or 0

    if currentPart < latestPart then
      return true
    end
  end

  return false
end

PerformHttpRequest(VERSION_URL, function(statusCode, response)
  if statusCode ~= 200 then
    return print("^1Unable to perform update check")
  end

  local currentVersion = GetResourceMetadata(GetCurrentResourceName(), "version", 0)
  if not currentVersion then
    return
  end

  if currentVersion == "dev" then
    return print("^3Using dev version")
  end

  local latestVersion = response:match("^[^\n]+")
  if not latestVersion then
    return
  end

  if isVersionNewer(currentVersion:sub(2), latestVersion:sub(2)) then
    print(("^3Update available for %s! (current: ^1%s^3, latest: ^2%s^3)"):format(RESOURCE_NAME, currentVersion, latestVersion))
    print("^3Release notes: discord.gg/jgscripts")
  end
end, "GET")

local function checkArtifactVersion()
  local serverVersion = GetConvar("version", "unknown")
  local artifactVersion = serverVersion:match("v%d+%.%d+%.%d+%.(%d+)")
  if not artifactVersion then
    return
  end

  PerformHttpRequest("https://artifacts.jgscripts.com/check?artifact=" .. artifactVersion, function(statusCode, response, _, errorData)
    if statusCode ~= 200 or errorData then
      return print("^1Could not check artifact version^0")
    end

    if not response then
      return
    end

    local artifactData = json.decode(response)
    if artifactData.status == "BROKEN" then
      print("^1WARNING: The current FXServer version you are using (artifacts version) has known issues. Please update to the latest stable artifacts: https://artifacts.jgscripts.com^0")
      print("^0Artifact version:^3", artifactVersion, "\n\n^0Known issues:^3", artifactData.reason, "^0")
    end
  end)
end

CreateThread(function()
  checkArtifactVersion()
end)
