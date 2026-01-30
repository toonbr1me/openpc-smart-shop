-- API для работы с переносной ME ячейкой через транспозер
-- Читает содержимое ячейки и позволяет манипулировать предметами

local component = require("component")
local sides = require("sides")

local cellAPI = {}

-- Инициализация транспозера
function cellAPI.init()
    if component.isAvailable("transposer") then
        cellAPI.transposer = component.transposer
        return true
    else
        return false, "Транспозер не найден!"
    end
end

-- Получить размер инвентаря на стороне
function cellAPI.getInventorySize(side)
    if not cellAPI.transposer then
        return nil, "Транспозер не инициализирован"
    end
    return cellAPI.transposer.getInventorySize(side)
end

-- Получить стек из слота
function cellAPI.getStackInSlot(side, slot)
    if not cellAPI.transposer then
        return nil, "Транспозер не инициализирован"
    end
    return cellAPI.transposer.getStackInSlot(side, slot)
end

-- Получить все предметы из инвентаря (ячейки)
function cellAPI.getAllItems(side)
    if not cellAPI.transposer then
        return nil, "Транспозер не инициализирован"
    end
    
    local size = cellAPI.getInventorySize(side)
    if not size then
        return nil, "Инвентарь не найден на этой стороне"
    end
    
    local items = {}
    for slot = 1, size do
        local stack = cellAPI.transposer.getStackInSlot(side, slot)
        if stack then
            table.insert(items, {
                slot = slot,
                name = stack.name,
                label = stack.label,
                size = stack.size,
                damage = stack.damage or 0,
                maxSize = stack.maxSize or 64
            })
        end
    end
    
    return items
end

-- Подсчитать количество определённого предмета
function cellAPI.countItem(side, itemName, damage)
    local items = cellAPI.getAllItems(side)
    if not items then return 0 end
    
    damage = damage or 0
    local count = 0
    
    for _, item in ipairs(items) do
        if item.name == itemName and (item.damage or 0) == damage then
            count = count + item.size
        end
    end
    
    return count
end

-- Найти руды в ячейке (сопоставляя с конфигом)
function cellAPI.findOres(side, exchangeRates)
    local items = cellAPI.getAllItems(side)
    if not items then return {} end
    
    local ores = {}
    
    for _, item in ipairs(items) do
        -- Проверяем есть ли этот предмет в курсах обмена
        if exchangeRates[item.name] then
            local oreName = item.name
            if not ores[oreName] then
                ores[oreName] = {
                    name = item.name,
                    label = item.label,
                    total = 0,
                    slots = {},
                    rate = exchangeRates[item.name]
                }
            end
            ores[oreName].total = ores[oreName].total + item.size
            table.insert(ores[oreName].slots, {
                slot = item.slot,
                size = item.size
            })
        end
    end
    
    return ores
end

-- Переместить предметы между сторонами
function cellAPI.transferItem(fromSide, toSide, amount, fromSlot, toSlot)
    if not cellAPI.transposer then
        return false, "Транспозер не инициализирован"
    end
    
    local transferred = cellAPI.transposer.transferItem(fromSide, toSide, amount, fromSlot, toSlot)
    return transferred > 0, transferred
end

-- Забрать определённое количество руды из ячейки
function cellAPI.extractOre(side, oreName, amount, targetSide)
    if not cellAPI.transposer then
        return false, 0
    end
    
    local items = cellAPI.getAllItems(side)
    if not items then return false, 0 end
    
    local extracted = 0
    
    for _, item in ipairs(items) do
        if item.name == oreName and extracted < amount then
            local toExtract = math.min(item.size, amount - extracted)
            local success, count = cellAPI.transferItem(side, targetSide, toExtract, item.slot)
            if success then
                extracted = extracted + count
            end
        end
    end
    
    return extracted >= amount, extracted
end

-- Проверить что ячейка на месте
function cellAPI.isCellPresent(side)
    local size = cellAPI.getInventorySize(side)
    return size ~= nil and size > 0
end

-- Получить информацию о ячейке
function cellAPI.getCellInfo(side)
    local size = cellAPI.getInventorySize(side)
    if not size then
        return nil
    end
    
    local items = cellAPI.getAllItems(side)
    local usedSlots = #items
    local totalItems = 0
    
    for _, item in ipairs(items) do
        totalItems = totalItems + item.size
    end
    
    return {
        slots = size,
        usedSlots = usedSlots,
        freeSlots = size - usedSlots,
        totalItems = totalItems
    }
end

return cellAPI
