-- ME API обёртка для работы с Applied Energistics 2
-- Требует: адаптер с ME Controller или ME Interface

local component = require("component")
local sides = require("sides")

local meAPI = {}

-- Инициализация ME компонента
function meAPI.init()
    if component.isAvailable("me_controller") then
        meAPI.me = component.me_controller
        meAPI.type = "controller"
        return true
    elseif component.isAvailable("me_interface") then
        meAPI.me = component.me_interface
        meAPI.type = "interface"
        return true
    else
        return false, "ME Controller или Interface не найден!"
    end
end

-- Получить список всех предметов в ME системе
function meAPI.getItems()
    if not meAPI.me then
        return nil, "ME не инициализирована"
    end
    return meAPI.me.getItemsInNetwork()
end

-- Найти предмет по имени
function meAPI.findItem(itemName, damage)
    local items = meAPI.getItems()
    if not items then return nil end
    
    damage = damage or 0
    
    for _, item in pairs(items) do
        if item.name == itemName and (item.damage or 0) == damage then
            return item
        end
    end
    
    return nil
end

-- Проверить наличие предмета в ME
function meAPI.hasItem(itemName, amount, damage)
    local item = meAPI.findItem(itemName, damage)
    if not item then return false, 0 end
    
    local available = item.size or 0
    return available >= amount, available
end

-- Экспорт предмета из ME в инвентарь
-- targetSide - сторона куда экспортировать
-- itemName - название предмета
-- amount - количество
-- slot - целевой слот (опционально)
function meAPI.exportItem(targetSide, itemName, amount, damage, slot)
    if not meAPI.me then
        return false, "ME не инициализирована"
    end
    
    damage = damage or 0
    
    -- Формируем фильтр для экспорта
    local filter = {
        name = itemName,
        damage = damage
    }
    
    -- Экспортируем
    local exported = meAPI.me.exportItem(filter, targetSide, amount, slot)
    
    if exported and exported.size and exported.size > 0 then
        return true, exported.size
    else
        return false, 0
    end
end

-- Импорт предмета в ME из инвентаря
-- sourceSide - сторона откуда импортировать
-- slot - слот источника (опционально, если nil - все слоты)
function meAPI.importItem(sourceSide, slot)
    if not meAPI.me then
        return false, "ME не инициализирована"
    end
    
    if slot then
        local imported = meAPI.me.importItem({}, sourceSide, 64, slot)
        if imported and imported.size and imported.size > 0 then
            return true, imported.size
        end
        return false, 0
    else
        -- Импортируем все предметы
        local total = 0
        for s = 1, 64 do
            local imported = meAPI.me.importItem({}, sourceSide, 64, s)
            if imported and imported.size then
                total = total + imported.size
            end
        end
        return total > 0, total
    end
end

-- Получить информацию о ME сети
function meAPI.getNetworkInfo()
    if not meAPI.me then
        return nil, "ME не инициализирована"
    end
    
    return {
        type = meAPI.type,
        storedPower = meAPI.me.getStoredPower and meAPI.me.getStoredPower() or 0,
        maxPower = meAPI.me.getMaxStoredPower and meAPI.me.getMaxStoredPower() or 0,
        avgPower = meAPI.me.getAvgPowerUsage and meAPI.me.getAvgPowerUsage() or 0
    }
end

return meAPI
