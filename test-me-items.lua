-- Тестовая программа для анализа предметов из ME системы
-- Показывает ВСЕ доступные характеристики предметов

local component = require("component")
local serialization = require("serialization")
local term = require("term")

-- Цвета для вывода
local function colored(text, color)
    local gpu = component.gpu
    local oldColor = gpu.getForeground()
    gpu.setForeground(color)
    print(text)
    gpu.setForeground(oldColor)
end

local function printHeader(text)
    colored("\n" .. string.rep("=", 70), 0x4B4B4B)
    colored(text, 0x2196F3)
    colored(string.rep("=", 70), 0x4B4B4B)
end

local function printSuccess(text)
    colored("✓ " .. text, 0x4CAF50)
end

local function printError(text)
    colored("✗ " .. text, 0xF44336)
end

local function printWarning(text)
    colored("⚠ " .. text, 0xFFEB3B)
end

local function printInfo(text)
    colored("  " .. text, 0xFFFFFF)
end

-- Рекурсивный вывод таблицы
local function printTable(tbl, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            print(prefix .. tostring(k) .. " = {")
            printTable(v, indent + 1)
            print(prefix .. "}")
        else
            print(prefix .. tostring(k) .. " = " .. tostring(v))
        end
    end
end

printHeader("ДИАГНОСТИКА ME СИСТЕМЫ И ПРЕДМЕТОВ")

-- Шаг 1: Поиск ME Controller
printInfo("Поиск ME Controller...")
if not component.isAvailable("me_controller") then
    printError("ME Controller не найден!")
    printWarning("Убедитесь что:")
    printInfo("  - Adapter подключен к ME Interface/Controller")
    printInfo("  - ME система включена")
    printInfo("  - Кабели правильно соединены")
    return
end

local me = component.me_controller
printSuccess("ME Controller найден: " .. me.address:sub(1, 8))

-- Шаг 2: Проверка доступных методов
printHeader("ДОСТУПНЫЕ МЕТОДЫ ME CONTROLLER")
local methods = {}
for k, v in pairs(me) do
    if type(v) == "function" then
        table.insert(methods, k)
    end
end
table.sort(methods)

for _, method in ipairs(methods) do
    printInfo("• " .. method .. "()")
end

-- Шаг 3: Проверка состояния ME системы
printHeader("ПРОВЕРКА СОСТОЯНИЯ ME СИСТЕМЫ")

-- Проверяем энергию
if me.getEnergyStored then
    local energy = me.getEnergyStored()
    printInfo("Энергия в ME: " .. tostring(energy))
    if energy and energy > 0 then
        printSuccess("ME система имеет энергию!")
    else
        printError("ME система БЕЗ энергии!")
    end
end

-- Проверяем использование каналов
if me.getUsedChannels then
    local channels = me.getUsedChannels()
    printInfo("Используется каналов: " .. tostring(channels))
end

-- Проверяем подключенные устройства
if me.getConnectedDevices then
    local devices = me.getConnectedDevices()
    printInfo("Подключено устройств: " .. tostring(devices))
end

-- Шаг 4: Получение предметов
printHeader("ПОЛУЧЕНИЕ СПИСКА ПРЕДМЕТОВ")

local items = nil
local method_used = nil

-- Метод 1: getItemsInNetwork() без параметров
if me.getItemsInNetwork then
    printInfo("Попытка 1: me.getItemsInNetwork()")
    local success, result = pcall(function() return me.getItemsInNetwork() end)
    printInfo("  Результат: success=" .. tostring(success) .. ", result=" .. tostring(result) .. ", type=" .. type(result))
    
    if success and result and type(result) == "table" and #result > 0 then
        items = result
        method_used = "getItemsInNetwork()"
        printSuccess("Успех! Используем getItemsInNetwork()")
    elseif success and result and type(result) == "table" and #result == 0 then
        printWarning("getItemsInNetwork() вернул пустую таблицу - в ME нет предметов?")
        items = result
        method_used = "getItemsInNetwork() [пусто]"
    else
        printError("getItemsInNetwork() не работает")
    end
end

-- Метод 2: getItemsInNetwork() с фильтром
if not items and me.getItemsInNetwork then
    printInfo("Попытка 2: me.getItemsInNetwork({})")
    local success, result = pcall(function() return me.getItemsInNetwork({}) end)
    printInfo("  Результат: " .. tostring(result) .. ", type=" .. type(result))
    
    if success and result and type(result) == "table" and #result > 0 then
        items = result
        method_used = "getItemsInNetwork({})"
        printSuccess("Успех с параметром {}!")
    end
end

-- Метод 3: getAvailableItems
if not items and me.getAvailableItems then
    printInfo("Попытка 3: me.getAvailableItems()")
    local success, result = pcall(function() return me.getAvailableItems() end)
    printInfo("  Результат: " .. tostring(result) .. ", type=" .. type(result))
    
    if success and result and type(result) == "table" and #result > 0 then
        items = result
        method_used = "getAvailableItems()"
        printSuccess("Успех!")
    end
end

-- Метод 4: allItems
if not items and me.allItems then
    printInfo("Попытка 4: me.allItems()")
    local success, result = pcall(function() return me.allItems() end)
    printInfo("  Результат: " .. tostring(result) .. ", type=" .. type(result))
    
    if success and result and type(result) == "table" and #result > 0 then
        items = result
        method_used = "allItems()"
        printSuccess("Успех!")
    end
end

-- Метод 5: getAvailableItems с параметром
if not items and me.getAvailableItems then
    printInfo("Попытка 5: me.getAvailableItems({})")
    local success, result = pcall(function() return me.getAvailableItems({}) end)
    printInfo("  Результат: " .. tostring(result) .. ", type=" .. type(result))
    
    if 5uccess and result and type(result) == "table" and #result > 0 then
        items = result
        method_used = "getAvailableItems({})"
        printSuccess("Успех!")
    end
end

-- Метод 6: store
if not items and me.store then
    printInfo("Попытка 6: me.store()")
    local success, result = pcall(function() 
        -- store возвращает информацию о хранилище
        return me.store()
    end)
    printInfo("  Результат: " .. tostring(result) .. ", type=" .. type(result))
end

if not items or #items == 0 then
    print("\n")
    printError("НЕ УДАЛОСЬ ПОЛУЧИТЬ ПРЕДМЕТЫ!")
    print("\n")
    printWarning("Возможные причины:")
    printInfo("1. В ME системе НЕТ предметов")
    printInfo("2. ME система не подключена к хранилищу")
    printInfo("3. ME Interface не подключен к Adapter")
    printInfo("4. Версия AE2 несовместима с OpenComputers")
    print("\n")
    printWarning("ЧТО ДЕЛАТЬ:")
    printInfo("1. Положите ЛЮБЫЕ предметы в ME систему")
    printInfo("2. Убедитесь что ME Controller горит (есть энергия)")
    printInfo("3. Проверьте что есть ME Drive с ячейками")
    printInfo("4. Перезапустите тест")
    print("\n")
    colored("Нажмите любую клавишу для выхода...", 0x4B4B4B)
    io.read()
    return
end

printSuccess("Метод: " .. method_used)
printSuccess("Найдено предметов: " .. #items)

-- Шаг 4: Детальный анализ первых 3 предметов
printHeader("ДЕТАЛЬНЫЙ АНАЛИЗ ПРЕДМЕТОВ (первые 3)")

for i = 1, math.min(3, #items) do
    local item = items[i]
    
    colored("\n" .. string.rep("-", 70), 0x4B4B4B)
    colored("ПРЕДМЕТ #" .. i, 0x2196F3)
    colored(string.rep("-", 70), 0x4B4B4B)
    
    -- Показываем ВСЕ поля предмета
    printInfo("Все доступные поля:")
    for key, value in pairs(item) do
        if type(value) == "table" then
            print("  " .. key .. " = <таблица>")
        else
            print("  " .. key .. " = " .. tostring(value))
        end
    end
    
    -- Проверка основных полей
    print("\nОсновные характеристики:")
    printInfo("name: " .. tostring(item.name))
    printInfo("label: " .. tostring(item.label))
    printInfo("size: " .. tostring(item.size))
    printInfo("damage: " .. tostring(item.damage))
    printInfo("maxSize: " .. tostring(item.maxSize))
    printInfo("hasTag: " .. tostring(item.hasTag))
    
    -- Попытка получить NBT данные разными способами
    print("\nПроверка NBT данных:")
    
    if item.tag then
        printSuccess("item.tag существует!")
        print("\nСодержимое item.tag:")
        printTable(item.tag, 1)
    else
        printWarning("item.tag НЕ существует")
    end
    
    if item.nbt then
        printSuccess("item.nbt существует!")
        print("\nСодержимое item.nbt:")
        printTable(item.nbt, 1)
    else
        printWarning("item.nbt НЕ существует")
    end
    
    if item.tag and item.tag.display then
        printSuccess("item.tag.display существует!")
        
        if item.tag.display.Lore then
            printSuccess("item.tag.display.Lore найден!")
            print("\nСодержимое Lore:")
            for j, line in ipairs(item.tag.display.Lore) do
                print("  [" .. j .. "] " .. line)
            end
        else
            printWarning("item.tag.display.Lore НЕ существует")
        end
        
        if item.tag.display.Name then
            printSuccess("item.tag.display.Name: " .. item.tag.display.Name)
        end
    else
        printWarning("item.tag.display НЕ существует")
    end
    
    -- Попытка использовать getItemDetail если доступен
    print("\nПопытка получить детали через me.getItemDetail():")
    if me.getItemDetail then
        local success, detail = pcall(function()
            return me.getItemDetail({
                name = item.name,
                damage = item.damage or 0
            })
        end)
        
        if success and detail then
            printSuccess("getItemDetail() работает!")
            print("\nПолная информация:")
            printTable(detail, 1)
        else
            printError("getItemDetail() не работает: " .. tostring(detail))
        end
    else
        printWarning("me.getItemDetail() недоступен")
    end
    
    -- Сериализация всего предмета
    print("\nПолная сериализация предмета:")
    local success, serialized = pcall(function()
        return serialization.serialize(item, 100)
    end)
    
    if success then
        print(serialized)
    else
        printError("Не удалось сериализовать: " .. tostring(serialized))
    end
end

-- Шаг 6: Поиск предметов с описанием
printHeader("ПОИСК ПРЕДМЕТОВ С ОПИСАНИЕМ/ЦЕНОЙ")

local itemsWithLore = 0
local itemsWithPrice = 0

for i, item in ipairs(items) do
    local hasLore = false
    local hasPrice = false
    
    if item.tag and item.tag.display and item.tag.display.Lore then
        hasLore = true
        itemsWithLore = itemsWithLore + 1
        
        -- Проверяем есть ли цена
        for _, line in ipairs(item.tag.display.Lore) do
            if string.find(line, "%d+%.%d+") or 
               string.find(line, "цена") or 
               string.find(line, "price") or
               string.find(line, "%$") then
                hasPrice = true
                itemsWithPrice = itemsWithPrice + 1
                break
            end
        end
    end
    
    if hasLore then
        print("\n" .. (item.label or item.name))
        if hasPrice then
            printSuccess("  ✓ Есть Lore И возможно есть цена!")
        else
            printWarning("  ✓ Есть Lore, но цены не видно")
        end
        
        if item.tag.display.Lore then
            for j, line in ipairs(item.tag.display.Lore) do
                print("    " .. line)
            end
        end
    end
end

print("\n")
printHeader("ИТОГИ")
printInfo("Всего предметов: " .. #items)
printInfo("С Lore: " .. itemsWithLore .. " (" .. math.floor(itemsWithLore / #items * 100) .. "%)")
printInfo("С ценой: " .. itemsWithPrice .. " (" .. math.floor(itemsWithPrice / #items * 100) .. "%)")

if itemsWithLore == 0 then
    print("\n")
    printError("НИ У ОДНОГО предмета нет Lore!")
    printWarning("Это значит:")
    printInfo("  1. ME API на вашем сервере НЕ возвращает NBT данные")
    printInfo("  2. Парсинг цен из описания НЕВОЗМОЖЕН")
    printInfo("  3. Необходимо использовать config.lua с ценами")
    print("\n")
    colored("РЕШЕНИЕ: Создайте config.lua с ценами предметов вручную", 0xFFEB3B)
    colored("См. файл test-config.lua для примера", 0xFFEB3B)
elseif itemsWithPrice > 0 then
    print("\n")
    printSuccess("ОТЛИЧНО! Парсинг цен ВОЗМОЖЕН!")
    printInfo("Найдены предметы с информацией о цене в Lore")
else
    print("\n")
    printWarning("Lore есть, но цены в формате не найдены")
    printInfo("Возможно нужно:")
    printInfo("  1. Добавить цены в описание предметов")
    printInfo("  2. Или использовать config.lua")
end

print("\n")
colored("Тест завершен! Нажмите любую клавишу...", 0x4B4B4B)
io.read()
