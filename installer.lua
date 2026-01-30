-- One-shot installer for openpc-smart-shop
-- Usage on OC: wget https://raw.githubusercontent.com/toonbr1me/openpc-smart-shop/main/installer.lua installer.lua
-- then: lua installer.lua

local internet = require("internet")
local filesystem = require("filesystem")

local base = "https://raw.githubusercontent.com/toonbr1me/openpc-smart-shop/main"
local files = {
  {remote = "/config/app.lua", localPath = "/config/app.lua"},
  {remote = "/config/ae.lua", localPath = "/config/ae.lua"},
  {remote = "/config/rules.lua", localPath = "/config/rules.lua"},
  {remote = "/scripts/exchanger.lua", localPath = "/scripts/exchanger.lua"},
  {remote = "/scripts/install.lua", localPath = "/scripts/install.lua"},
  {remote = "/scripts/rc_exchanger.lua", localPath = "/scripts/rc_exchanger.lua"},
  {remote = "/README.md", localPath = "/README.md"}
}

local function ensureDirs()
  local dirs = {"/config", "/scripts"}
  for _, d in ipairs(dirs) do
    if not filesystem.exists(d) then
      filesystem.makeDirectory(d)
    end
  end
end

local function fetch(url)
  local handle, err = internet.request(url)
  if not handle then
    return nil, "request failed: " .. tostring(err)
  end
  local buf = {}
  for chunk in handle do
    buf[#buf + 1] = chunk
  end
  return table.concat(buf)
end

local function writeFile(path, data)
  local fh, err = io.open(path, "w")
  if not fh then return nil, err end
  fh:write(data)
  fh:close()
  return true
end

local function install()
  if not internet then
    io.stderr:write("Internet component required.\n")
    return false
  end

  ensureDirs()

  local okCount = 0
  for _, f in ipairs(files) do
    io.write("Fetching " .. f.remote .. " ... ")
    local body, err = fetch(base .. f.remote)
    if not body then
      print("FAIL: " .. tostring(err))
    else
      local ok, werr = writeFile(f.localPath, body)
      if not ok then
        print("FAIL: cannot write: " .. tostring(werr))
      else
        print("OK")
        okCount = okCount + 1
      end
    end
  end

  print(string.format("Done. %d/%d files updated.", okCount, #files))
  print("Next: run 'lua /scripts/install.lua' to set addresses/sides, then 'lua /scripts/exchanger.lua' or enable rc service.")
end

install()
