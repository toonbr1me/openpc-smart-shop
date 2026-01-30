-- Interactive installer for exchanger config (ae.lua)
-- Run on the OC machine: lua /scripts/install.lua

local component = require("component")
local sides = require("sides")
local filesystem = require("filesystem")

local function collect(kind)
  local list = {}
  for addr in component.list(kind) do
    list[#list + 1] = addr
  end
  return list
end

local function choose(list, label)
  if #list == 0 then
    io.stderr:write("Не найдено компонентов: " .. label .. "\n")
    os.exit(1)
  end
  print("Выберите " .. label .. ":")
  for i, addr in ipairs(list) do
    print(string.format("  %d) %s", i, addr))
  end
  while true do
    io.write(string.format("Номер [1-%d]: ", #list))
    local n = tonumber(io.read())
    if n and n >= 1 and n <= #list then return list[n] end
    print("Некорректный ввод, повторите.")
  end
end

local function chooseSide(prompt, defaultName)
  local valid = {}
  for name, num in pairs(sides) do
    if type(num) == "number" then valid[#valid + 1] = name end
  end
  table.sort(valid)
  while true do
    io.write(string.format("%s (доступно: %s) [%s]: ", prompt, table.concat(valid, ","), defaultName))
    local line = io.read()
    if not line or line == "" then line = defaultName end
    if sides[line] then return line end
    print("Некорректная сторона, попробуйте ещё раз.")
  end
end

local function writeFile(path, content)
  local fh, err = io.open(path, "w")
  if not fh then
    io.stderr:write("Не удалось записать " .. path .. ": " .. tostring(err) .. "\n")
    os.exit(1)
  end
  fh:write(content)
  fh:close()
end

local function main()
  local transposers = collect("transposer")
  local interfaces = collect("me_interface")

  local transposerAddr = choose(transposers, "transposer")
  local processingIf = choose(interfaces, "processing me_interface (сеть ячейки)")
  local mainIf = choose(interfaces, "main me_interface (основная сеть)")

  print("Теперь задайте стороны относительно transposer/интерфейсов.")
  local bufferSide = chooseSide("bufferSide (сундук игрока)", "north")
  local processChestSide = chooseSide("processChestSide (ME Chest c ячейкой)", "east")
  local dropSide = chooseSide("dropSide (выдача готовой ячейки)", "west")
  local processingTrashSide = chooseSide("processingTrashSide (мусор/void)", "top")
  local mainOutputSide = chooseSide("mainOutputSide (куда главный ME кладёт выплаты)", "south")
  local fillChestSide = chooseSide("fillChestSideOnTransposer (та же fill chest)", "south")

  local path = "/config/ae.lua"
  local template = string.format([[local sides = require("sides")

return {
  transposer = "%s",
  bufferSide = sides.%s,
  processChestSide = sides.%s,
  dropSide = sides.%s,

  processingInterface = "%s",
  mainInterface = "%s",

  processingTrashSide = sides.%s,
  mainOutputSide = sides.%s,

  fillChestSideOnTransposer = sides.%s,

  logPath = "/var/log/exchanger.log"
}
]], transposerAddr, bufferSide, processChestSide, dropSide, processingIf, mainIf, processingTrashSide, mainOutputSide, fillChestSide)

  if not filesystem.exists("/config") then filesystem.makeDirectory("/config") end
  writeFile(path, template)
  print("Готово. Конфиг записан в " .. path)
end

main()
