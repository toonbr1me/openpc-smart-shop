-- Модуль для парсинга цен из NBT Lore через Database
-- Использование: local parser = require("price-parser")
--                local price = parser.getPriceForItem(me, db, itemName, damage, dbSlot)

local priceParser = {}

-- Паттерны для поиска цены в строках Lore
local PRICE_PATTERNS = {
    "Минимальная цена:%s*([%d%.]+)%$",  -- "Минимальная цена: 15.0$"
    "Цена:%s*([%d%.]+)%$",                -- "Цена: 15.0$"
    "Price:%s*([%d%.]+)%$",               -- "Price: 15.0$"
    "Стоимость:%s*([%d%.]+)%$",           -- "Стоимость: 15.0$"
    "(%d+%.%d+)%$",                       -- Просто "15.0$"
    "(%d+)%$"                             -- Просто "15$"
}

-- Парсит цену из одной строки Lore
-- @param line string - строка из Lore
-- @return number|nil - найденная цена или nil
function priceParser.parsePriceFromLine(line)
    if not line or type(line) ~= "string" then
        return nil
    end
    
    -- Пробуем все паттерны
    for _, pattern in ipairs(PRICE_PATTERNS) do
        local priceStr = line:match(pattern)
        if priceStr then
            local price = tonumber(priceStr)
            if price and price > 0 then
                return price
            end
        end
    end
    
    return nil
end

-- Парсит цену из массива строк Lore
-- @param loreLines table - массив строк из tag.display.Lore
-- @return number|nil - найденная цена или nil
function priceParser.parsePriceFromLore(loreLines)
    if not loreLines or type(loreLines) ~= "table" then
        return nil
    end
    
    -- Проходим по всем строкам
    for _, line in ipairs(loreLines) do
        local price = priceParser.parsePriceFromLine(line)
        if price then
            return price
        end
    end
    
    return nil
end

-- Получает NBT данные предмета через Database
-- @param me component - ME Controller
-- @param db component - Database
-- @param itemName string - ID предмета (например "minecraft:diamond")
-- @param damage number - Damage/metadata (обычно 0)
-- @param dbSlot number - слот в Database для временного хранения
-- @return table|nil - полные данные предмета с NBT или nil
function priceParser.getItemNBT(me, db, itemName, damage, dbSlot)
    if not me or not db or not itemName or not dbSlot then
        return nil
    end
    
    damage = damage or 0
    
    -- Очищаем слот
    db.clear(dbSlot)
    
    -- Сохраняем предмет в Database
    local filter = {
        name = itemName,
        damage = damage
    }
    
    local success = me.store(filter, db.address, dbSlot, 1)
    
    if not success then
        return nil
    end
    
    -- Получаем полные данные
    local itemData = db.get(dbSlot)
    
    -- Очищаем слот после использования
    db.clear(dbSlot)
    
    return itemData
end

-- ГЛАВНАЯ ФУНКЦИЯ: Получает цену для конкретного предмета
-- @param me component - ME Controller
-- @param db component - Database
-- @param itemName string - ID предмета
-- @param damage number - Damage/metadata (необязательно)
-- @param dbSlot number - слот в Database (необязательно, по умолчанию 1)
-- @return number|nil - цена предмета или nil если не найдена
function priceParser.getPriceForItem(me, db, itemName, damage, dbSlot)
    dbSlot = dbSlot or 1
    damage = damage or 0
    
    -- Получаем NBT данные
    local itemData = priceParser.getItemNBT(me, db, itemName, damage, dbSlot)
    
    if not itemData then
        return nil
    end
    
    -- Пытаемся найти Lore в NBT
    local lore = nil
    
    -- Проверяем tag.display.Lore
    if itemData.tag and itemData.tag.display and itemData.tag.display.Lore then
        lore = itemData.tag.display.Lore
    -- Проверяем nbt.display.Lore (альтернативная структура)
    elseif itemData.nbt and itemData.nbt.display and itemData.nbt.display.Lore then
        lore = itemData.nbt.display.Lore
    end
    
    if not lore then
        return nil
    end
    
    -- Парсим цену из Lore
    return priceParser.parsePriceFromLore(lore)
end

-- Получает цены для списка предметов (оптимизированный batch режим)
-- @param me component - ME Controller
-- @param db component - Database
-- @param items table - список предметов {name, damage}
-- @param startSlot number - начальный слот в Database (по умолчанию 1)
-- @return table - таблица {[itemKey] = price}
function priceParser.getPricesForItems(me, db, items, startSlot)
    startSlot = startSlot or 1
    local prices = {}
    local currentSlot = startSlot
    
    for i, item in ipairs(items) do
        local itemKey = item.name .. ":" .. (item.damage or 0)
        local price = priceParser.getPriceForItem(me, db, item.name, item.damage, currentSlot)
        
        if price then
            prices[itemKey] = price
        end
        
        -- Используем следующий слот (циклически, если Database маленький)
        currentSlot = currentSlot + 1
        if currentSlot > 81 then  -- Database имеет 81 слот (Tier 3)
            currentSlot = startSlot
        end
        
        -- Небольшая задержка чтобы не перегружать систему
        if i % 10 == 0 then
            os.sleep(0.05)
        end
    end
    
    return prices
end

return priceParser
