-- Тестовый конфигурационный файл для Smart Shop
-- Используйте этот файл если парсинг цены из описания не работает

-- ИНСТРУКЦИЯ ПО ИСПОЛЬЗОВАНИЮ:
-- 1. Скопируйте этот файл на компьютер OpenComputers как /home/config.lua
-- 2. В shop.lua раскомментируйте строки загрузки конфига
-- 3. Заполните таблицу priceList ценами ваших товаров

-- Формат: ["ID:metadata"] = цена
-- ID получить командой: /ct hand (при наличии CraftTweaker)
-- Или посмотреть в F3 + H режиме

local priceList = {
    -- Ванильные предметы
    ["minecraft:diamond"] = 100.0,
    ["minecraft:emerald"] = 50.0,
    ["minecraft:iron_ingot"] = 5.0,
    ["minecraft:gold_ingot"] = 10.0,
    
    -- Руды
    ["minecraft:diamond_ore"] = 150.0,
    ["minecraft:emerald_ore"] = 75.0,
    ["minecraft:iron_ore"] = 7.5,
    ["minecraft:gold_ore"] = 15.0,
    
    -- ContentTweaker предметы (пример)
    ["contenttweaker:custom_ingot"] = 25.5,
    ["contenttweaker:rare_gem"] = 200.0,
    
    -- Блоки
    ["minecraft:diamond_block"] = 900.0,
    ["minecraft:emerald_block"] = 450.0,
    
    -- Инструменты (с учетом damage/metadata если есть)
    ["minecraft:diamond_pickaxe"] = 300.0,
    ["minecraft:diamond_sword"] = 200.0,
    
    -- Еда
    ["minecraft:golden_apple"] = 50.0,
    ["minecraft:golden_apple:1"] = 500.0,  -- Зачарованное яблоко (metadata 1)
    
    -- Modded предметы (замените на ваши)
    ["thermalexpansion:machine"] = 100.0,
    ["mekanism:ingot:1"] = 15.0,  -- С metadata
}

-- Альтернативный метод: цены по категориям
local categoryPrices = {
    ["ore"] = 10.0,        -- Все руды
    ["ingot"] = 5.0,       -- Все слитки
    ["gem"] = 50.0,        -- Все драгоценности
    ["block"] = 50.0,      -- Все блоки
}

-- Функция получения цены предмета
local function getPrice(itemName, metadata)
    metadata = metadata or 0
    
    -- Сначала ищем точное совпадение с metadata
    local fullName = metadata > 0 and (itemName .. ":" .. metadata) or itemName
    if priceList[fullName] then
        return priceList[fullName]
    end
    
    -- Затем без metadata
    if priceList[itemName] then
        return priceList[itemName]
    end
    
    -- Проверяем категории по ключевым словам
    local lowerName = itemName:lower()
    for category, price in pairs(categoryPrices) do
        if lowerName:find(category) then
            return price
        end
    end
    
    -- Дефолтная цена
    return 10.0
end

-- Экспорт
return {
    priceList = priceList,
    categoryPrices = categoryPrices,
    getPrice = getPrice
}
