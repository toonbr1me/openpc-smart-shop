-- Экспорт списка предметов с ценами в файл
-- Использование: export_prices [имя_файла]

local component = require("component")
local unicode = require("unicode")
local serialization = require("serialization")
local filesystem = require("filesystem")
local args = {...}

-- Проверка наличия ME компонента
local me = component.me_interface or component.me_controller or component.me_exportbus or component.me_importbus

if not me then
    print("ОШИБКА: ME компонент не найден!")
    return
end

-- Функция для парсинга цены
local function parsePrice(itemData)
    if not itemData.label then
        return nil
    end
    
    local pricePatterns = {
        "цена:%s*([%d%.]+)%$",
        "Минимальная цена:%s*([%d%.]+)%$",
        "Price:%s*([%d%.]+)%$",
        "([%d%.]+)%$"
    }
    
    for _, pattern in ipairs(pricePatterns) do
        local price = itemData.label:match(pattern)
        if price then
            return tonumber(price)
        end
    end
    
    return nil
end

-- Функция для получения имени предмета
local function getItemName(itemData)
    return itemData.label or itemData.name or "Неизвестный предмет"
end

-- Основная логика
local filename = args[1] or "prices.txt"

print("Экспорт данных из ME системы...")
print("")

local items = me.getItemsInNetwork()

if not items then
    print("Не удалось получить список предметов")
    return
end

-- Сортируем по наличию цены и названию
table.sort(items, function(a, b)
    local priceA = parsePrice(a)
    local priceB = parsePrice(b)
    
    if priceA and not priceB then
        return true
    elseif not priceA and priceB then
        return false
    end
    
    return getItemName(a) < getItemName(b)
end)

-- Открываем файл для записи
local file, err = io.open(filename, "w")
if not file then
    print("Ошибка открытия файла: " .. tostring(err))
    return
end

-- Записываем заголовок
file:write("=======================================================================\n")
file:write("              ЭКСПОРТ ПРЕДМЕТОВ ИЗ ME СИСТЕМЫ\n")
file:write("              " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
file:write("=======================================================================\n\n")

local totalItems = 0
local itemsWithPrice = 0
local totalValue = 0

-- Записываем предметы
for _, item in ipairs(items) do
    local name = getItemName(item)
    local size = item.size or 0
    local price = parsePrice(item)
    local itemID = item.name or "N/A"
    
    totalItems = totalItems + 1
    
    file:write(string.format("Предмет: %s\n", name))
    file:write(string.format("ID: %s\n", itemID))
    file:write(string.format("Количество: %d\n", size))
    
    if price then
        itemsWithPrice = itemsWithPrice + 1
        local itemValue = price * size
        totalValue = totalValue + itemValue
        file:write(string.format("Цена за единицу: %.2f$\n", price))
        file:write(string.format("Общая стоимость: %.2f$\n", itemValue))
    else
        file:write("Цена: не указана\n")
    end
    
    file:write("-----------------------------------------------------------------------\n")
end

-- Записываем статистику
file:write("\n")
file:write("=======================================================================\n")
file:write("                           СТАТИСТИКА\n")
file:write("=======================================================================\n")
file:write(string.format("Всего уникальных предметов: %d\n", totalItems))
file:write(string.format("Предметов с ценами: %d\n", itemsWithPrice))
file:write(string.format("Общая стоимость всех предметов: %.2f$\n", totalValue))
file:write("=======================================================================\n")

file:close()

-- Вывод результатов
print("Экспорт завершен!")
print("")
print("Файл: " .. filename)
print("Всего предметов: " .. totalItems)
print("С ценами: " .. itemsWithPrice)
print("Общая стоимость: " .. string.format("%.2f$", totalValue))

-- Также создаем JSON версию для машинной обработки
local jsonFilename = filename:gsub("%.txt$", "") .. ".json"
local jsonFile, jsonErr = io.open(jsonFilename, "w")

if jsonFile then
    local exportData = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        totalItems = totalItems,
        itemsWithPrice = itemsWithPrice,
        totalValue = totalValue,
        items = {}
    }
    
    for _, item in ipairs(items) do
        table.insert(exportData.items, {
            name = getItemName(item),
            id = item.name,
            quantity = item.size or 0,
            price = parsePrice(item)
        })
    end
    
    jsonFile:write(serialization.serialize(exportData, true))
    jsonFile:close()
    print("JSON экспорт: " .. jsonFilename)
end
