local function splitSqlStatements(sql, separator)
  local statements = {}

  for statement in string.gmatch(sql, "([^" .. separator .. "]+)") do
    statements[#statements + 1] = statement:gsub("^%s*(.-)%s*$", "%1")
  end

  return statements
end

function initSQL()
  if not Config.AutoRunSQL then
    return
  end

  local ok = pcall(function()
    local fileName = (Config.Framework == "QBCore" or Config.Framework == "Qbox") and "run-qb.sql" or "run-esx.sql"
    local filePath = ("%s/install/%s"):format(GetResourcePath(GetCurrentResourceName()), fileName)
    local file = assert(io.open(filePath, "rb"))
    local sql = file:read("*all")
    file:close()

    MySQL.transaction.await(splitSqlStatements(sql, ";"))
  end)

  if not ok then
    print("^1[SQL ERROR] There was an error while automatically running the required SQL. Don't worry, you just need to run the SQL file for your framework, found in the 'install' folder manually. If you've already ran the SQL code previously, and this error is annoying you, set Config.AutoRunSQL = false^0")
  end
end
