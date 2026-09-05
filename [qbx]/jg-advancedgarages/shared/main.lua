Functions = {}

Locale = Locales[Config.Locale or "en"]

Globals = {
  OutsideVehicles = {}
}

function debugPrint(source, level, ...)
  if not Config.Debug then
    return
  end

  local prefix = "^2[DEBUG]^7"
  if level == "warning" then
    prefix = "^3[WARNING]^7"
  end

  local args = {...}
  local message = ""

  for index, value in ipairs(args) do
    if type(value) == "table" then
      message = message .. json.encode(value)
    elseif type(value) == "string" then
      message = message .. value
    else
      message = message .. tostring(value)
    end

    if index ~= #args then
      message = message .. " "
    end
  end

  print(prefix, source, message)
end

function setVehiclePlateText(vehicle, plate)
  if GetResourceState("AdvancedParking") == "started" then
    exports.AdvancedParking:UpdatePlate(vehicle, plate)
  else
    SetVehicleNumberPlateText(vehicle, plate)
  end
end

function convertJSTimestamp(timestamp)
  local months = {
    Jan = 1,
    Feb = 2,
    Mar = 3,
    Apr = 4,
    May = 5,
    Jun = 6,
    Jul = 7,
    Aug = 8,
    Sep = 9,
    Oct = 10,
    Nov = 11,
    Dec = 12
  }

  local month, day, year, hour, min, sec = timestamp:match("%a+%s+(%a+)%s+(%d+)%s+(%d+)%s+(%d+):(%d+):(%d+)")

  return os.time({
    year = tonumber(year),
    month = months[month],
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec)
  })
end

function convertModelToHash(model)
  if type(model) == "string" then
    return joaat(model)
  end

  return model
end

function round(value, decimalPlaces)
  local multiplier = 10 ^ (decimalPlaces or 0)
  return math.floor(value * multiplier + 0.5) / multiplier
end

function isItemInList(list, item)
  if #list == 0 then
    return false
  end

  for _, listItem in ipairs(list) do
    if listItem == item then
      return true
    end
  end

  return false
end

function isValidGTAPlate(plate)
  return #plate <= 8 and plate:match("^[%w%s]*$") ~= nil
end

function tableKeys(tbl)
  local keys = {}

  for key in pairs(tbl) do
    keys[#keys + 1] = key
  end

  return keys
end

CreateThread(function()
  for model, label in pairs(Config.VehicleLabels) do
    Config.VehicleLabels[tostring(joaat(model))] = label
  end
end)
