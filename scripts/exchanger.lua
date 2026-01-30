-- Portable-cell ore exchanger for AE2 + OpenComputers
-- Steps per cycle:
-- 1) Move user's portable cell from buffer chest into an isolated ME Chest/drive (processing network).
-- 2) Read ores inside the cell via processing ME interface, compute payouts from rules.lua.
-- 3) If main ME has enough outputs, trash the ores, pull payout items from main ME into the fill chest.
--    The fill chest must have an Import Bus to the processing network so the payout lands inside the cell.
-- 4) Return the cell to the drop chest.

local component = require("component")
local event = require("event")
local serialization = require("serialization")
local sides = require("sides")
local fs = require("filesystem")
local os = require("os")

local app = dofile("/config/app.lua")
local ae = dofile("/config/ae.lua")
local rules = dofile("/config/rules.lua")

local function log(msg)
  local line = string.format("[%s] %s\n", os.date("%H:%M:%S"), msg)
  io.write(line)
  if ae.logPath then
    local ok, fh = pcall(io.open, ae.logPath, "a")
    if ok and fh then fh:write(line) fh:close() end
  end
end

local function proxyOrError(addr, kind)
  if not addr or not component.proxy(addr) then
    error(string.format("Missing %s component: %s", kind, tostring(addr)))
  end
  return component.proxy(addr)
end

local transposer = proxyOrError(ae.transposer, "transposer")
local processingInterface = proxyOrError(ae.processingInterface, "processing me_interface")
local mainInterface = proxyOrError(ae.mainInterface, "main me_interface")

local function sleep(sec)
  os.sleep(sec)
end

local function itemKey(item)
  return string.format("%s|%d|%s", item.name, item.damage or 0, item.nbt_hash or "")
end

local function matchRule(item)
  for _, rule in pairs(rules) do
    if rule.id and item.name == rule.id then return rule end
    if rule.nameContains and string.find(item.name, rule.nameContains, 1, true) then return rule end
  end
  return nil
end

local function findCellSlot()
  local size = transposer.getInventorySize(ae.bufferSide) or 0
  for slot = 1, size do
    local stack = transposer.getStackInSlot(ae.bufferSide, slot)
    if stack and stack.name and string.find(stack.name, "cell", 1, true) then
      return slot
    end
  end
  return nil
end

local function moveCellToProcessing(slot)
  local moved = transposer.transferItem(ae.bufferSide, ae.processChestSide, 1, slot, 1)
  if moved ~= 1 then
    return false, "cannot move cell to processing chest"
  end
  return true
end

local function returnCell()
  local moved = transposer.transferItem(ae.processChestSide, ae.dropSide, 1, 1, 1)
  if moved ~= 1 then
    return false, "cannot return cell to drop chest"
  end
  return true
end

local function readProcessingItems()
  local items = processingInterface.getItemsInNetwork()
  local ores = {}
  for _, it in ipairs(items) do
    local rule = matchRule(it)
    if rule then
      ores[#ores + 1] = { item = it, rule = rule }
    end
  end
  return ores
end

local function aggregateOres(entries)
  local counts = {}
  for _, e in ipairs(entries) do
    local key = itemKey(e.item)
    counts[key] = counts[key] or { item = e.item, rule = e.rule, count = 0 }
    counts[key].count = counts[key].count + e.item.size
  end
  local list = {}
  for _, v in pairs(counts) do list[#list + 1] = v end
  return list
end

local function computeOutputs(ores)
  local outputs = {}
  local totalIn = 0
  for _, entry in ipairs(ores) do
    local count = entry.count
    totalIn = totalIn + count
    local rule = entry.rule
    local blocks = math.floor(count / rule.blockCost)
    local rem = count % rule.blockCost

    if blocks > 0 then
      local key = itemKey(rule.block)
      outputs[key] = outputs[key] or { item = rule.block, count = 0 }
      outputs[key].count = outputs[key].count + blocks
    end
    if rule.bonus and rem == rule.bonus.whenRemainder then
      local key = itemKey(rule.bonus.item)
      outputs[key] = outputs[key] or { item = rule.bonus.item, count = 0 }
      outputs[key].count = outputs[key].count + 1
    elseif rem > 0 then
      local key = itemKey(rule.ingot)
      outputs[key] = outputs[key] or { item = rule.ingot, count = 0 }
      outputs[key].count = outputs[key].count + rem
    end
  end

  local list = {}
  local totalOut = 0
  for _, v in pairs(outputs) do
    totalOut = totalOut + v.count
    list[#list + 1] = v
  end
  return list, totalIn, totalOut
end

local function stockMap(items)
  local map = {}
  for _, it in ipairs(items) do
    map[itemKey(it)] = it.size
  end
  return map
end

local function hasAllStock(needs, stock)
  for _, need in ipairs(needs) do
    local have = stock[itemKey(need.item)] or 0
    if have < need.count then return false end
  end
  return true
end

local function exportOres(ores)
  for _, ore in ipairs(ores) do
    local toTrash = processingInterface.exportItem(ore.item, ae.processingTrashSide, ore.count)
    if not toTrash or toTrash.size ~= ore.count then
      return false, string.format("failed to trash %s x%d", ore.item.name, ore.count)
    end
  end
  return true
end

local function payout(outputs)
  local shortages = {}
  for _, out in ipairs(outputs) do
    local sent = mainInterface.exportItem(out.item, ae.mainOutputSide, out.count)
    local delivered = sent and sent.size or 0
    if delivered < out.count then
      shortages[#shortages + 1] = { item = out.item, needed = out.count, sent = delivered }
    end
  end
  return #shortages == 0, shortages
end

local function limitTotals(ores)
  local cap = app.maxItemsPerCycle or math.huge
  local used = 0
  local trimmed = {}
  for _, o in ipairs(ores) do
    if used >= cap then break end
    local left = cap - used
    local take = math.min(o.count, left)
    trimmed[#trimmed + 1] = { item = o.item, rule = o.rule, count = take }
    used = used + take
  end
  return trimmed
end

local function describeShortages(shortages)
  local parts = {}
  for _, s in ipairs(shortages) do
    parts[#parts + 1] = string.format("%s need %d got %d", s.item.name, s.needed, s.sent)
  end
  return table.concat(parts, "; ")
end

local function processOnce()
  local slot = findCellSlot()
  if not slot then return false end

  log("cell detected in buffer slot " .. slot)
  local ok, err = moveCellToProcessing(slot)
  if not ok then log(err) return true end
  sleep(app.waitAfterMoveSeconds)

  local rawOres = readProcessingItems()
  if #rawOres == 0 then
    log("no ores inside cell; returning")
    returnCell()
    return true
  end

  local ores = aggregateOres(rawOres)
  ores = limitTotals(ores)
  local outputs, totalIn, totalOut = computeOutputs(ores)

  local mainStock = stockMap(mainInterface.getItemsInNetwork())
  if app.requireFullPayout and not hasAllStock(outputs, mainStock) then
    log("skip: not enough stock in main ME for payout")
    returnCell()
    return true
  end

  local okTrash, errTrash = exportOres(ores)
  if not okTrash then
    log(errTrash)
    returnCell()
    return true
  end

  local okPay, shortages = payout(outputs)
  if not okPay then
    log("payout shortage: " .. describeShortages(shortages))
    if app.requireFullPayout then
      log("payout incomplete; cell returned empty of ores; consider refunding manually")
    end
  end

  sleep(app.waitAfterMoveSeconds)
  returnCell()
  log(string.format("done: in %d items -> out %d items", totalIn, totalOut))
  return true
end

log("exchanger daemon started")
while true do
  local progressed = false
  local ok, err = pcall(function()
    progressed = processOnce()
  end)
  if not ok then
    log("error: " .. tostring(err))
  end
  if not progressed then
    event.pull(app.pollSeconds)
  else
    event.pull(app.pollSeconds)
  end
end
