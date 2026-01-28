-- ME Shop - Программа для поиска предметов в ME системе и отображения цен
-- Требует: OpenComputers + Applied Energistics 2
-- Подключите ME Interface или ME Controller через Adapter

local component = require("component")
local unicode = require("unicode")
local term = require("term")
local text = require("text")
local serialization = require("serialization")

-- Проверка наличия ME компонента
local me = nil
local meTypes = {"me_interface", "me_controller", "me_exportbus", "me_importbus"}

for _, meType in ipairs(meTypes) do
    if component.isAvailable(meType) then
        me = component.getPrimary(meType)
        break
    end
end

if not me then
    print("ОШИБКА: ME компонент не найден!")
    print("Подключите ME Interface, ME Controller, ME Export Bus или ME Import Bus через Adapter")
    return
end

print("ME компонент найден: " .. component.getPrimary(me.type).address)
print("")

-- Функция для парсинга цены из описания предмета
local function parsePrice(itemData)
    if not itemData.label then
        return nil
    end
    
    -- Ищем цену в формате "Минимальная цена: X$" или "X$"
    -- Также поддержка вариантов: "цена: X$", "Price: X$"
    local pricePatterns = {
        "цена:%s*([%d%.]+)%$",           -- "цена: 2.25$"
        "Минимальная цена:%s*([%d%.]+)%$",  -- "Минимальная цена: 2.25$"
        "Price:%s*([%d%.]+)%$",          -- "Price: 2.25$"
        "([%d%.]+)%$"                    -- "2.25$"
    }
    
    -- Проверяем label (название предмета)
    for _, pattern in ipairs(pricePatterns) do
        local price = itemData.label:match(pattern)
        if price then
            return tonumber(price)
        end
    end
    
    return nil
end

-- Функция для получения читаемого имени предмета
local function getItemName(itemData)
    return itemData.label or itemData.name or "Неизвестный предмет"
end

-- Функция для отображения списка предметов с ценами
local function displayItems(items)
    if not items or #items == 0 then
        print("В ME системе нет предметов")
        return
    end
    
    print("=" .. string.rep("=", 78))
    print(string.format("%-50s %10s %12s", "Предмет", "Количество", "Цена"))
    print("=" .. string.rep("=", 78))
    
    local totalItems = 0
    local itemsWithPrice = 0
    local totalValue = 0
    
    for _, item in ipairs(items) do
        local name = getItemName(item)
        local size = item.size or 0
        local price = parsePrice(item)
        
        totalItems = totalItems + 1
        
        local priceStr = "-"
        if price then
            priceStr = string.format("%.2f$", price)
            itemsWithPrice = itemsWithPrice + 1
            totalValue = totalValue + (price * size)
        end
        
        -- Обрезаем длинные названия
        if unicode.len(name) > 48 then
            name = unicode.sub(name, 1, 45) .. "..."
        end
        
        print(string.format("%-50s %10d %12s", name, size, priceStr))
    end
    
    print("=" .. string.rep("=", 78))
    print(string.format("Всего предметов: %d | С ценами: %d | Общая стоимость: %.2f$", 
        totalItems, itemsWithPrice, totalValue))
    print("")
end

-- Функция для поиска предмета по названию
local function searchItem(searchQuery)
    print("Поиск предметов: '" .. searchQuery .. "'")
    print("")
    
    -- Получаем все предметы из сети
    local items = me.getItemsInNetwork()
    
    if not items then
        print("Не удалось получить список предметов из ME системы")
        return
    end
    
    -- Фильтруем по поисковому запросу
    local filtered = {}
    local queryLower = unicode.lower(searchQuery)
    
    for _, item in ipairs(items) do
        local name = getItemName(item)
        local nameLower = unicode.lower(name)
        
        if nameLower:find(queryLower, 1, true) then
            table.insert(filtered, item)
        end
    end
    
    displayItems(filtered)
end

-- Функция для отображения всех предметов
local function listAllItems()
    print("Загрузка всех предметов из ME системы...")
    print("")
    
    local items = me.getItemsInNetwork()
    
    if not items then
        print("Не удалось получить список предметов из ME системы")
        return
    end
    
    displayItems(items)
end

-- Функция для отображения только предметов с ценами
local function listItemsWithPrices()
    print("Загрузка предметов с ценами...")
    print("")
    
    local items = me.getItemsInNetwork()
    
    if not items then
        print("Не удалось получить список предметов из ME системы")
        return
    end
    
    -- Фильтруем только предметы с ценами
    local filtered = {}
    for _, item in ipairs(items) do
        if parsePrice(item) then
            table.insert(filtered, item)
        end
    end
    
    displayItems(filtered)
end

-- Функция для получения детальной информации о предмете
local function getItemDetails(itemName)
    print("Получение информации о предмете: '" .. itemName .. "'")
    print("")
    
    local items = me.getItemsInNetwork()
    
    if not items then
        print("Не удалось получить список предметов из ME системы")
        return
    end
    
    local queryLower = unicode.lower(itemName)
    
    for _, item in ipairs(items) do
        local name = getItemName(item)
        local nameLower = unicode.lower(name)
        
        if nameLower:find(queryLower, 1, true) then
            print("Предмет найден!")
            print("")
            print("Название: " .. name)
            print("ID: " .. (item.name or "N/A"))
            print("Количество: " .. (item.size or 0))
            
            local price = parsePrice(item)
            if price then
                print("Цена за единицу: " .. string.format("%.2f$", price))
                print("Общая стоимость: " .. string.format("%.2f$", price * (item.size or 0)))
            else
                print("Цена: не указана")
            end
            
            print("")
            print("Полная информация:")
            print(serialization.serialize(item, true))
            print("")
            return
        end
    end
    
    print("Предмет не найден")
end

-- Главное меню
local function showMenu()
    while true do
        term.clear()
        print("╔═══════════════════════════════════════════════════════╗")
        print("║             ME SHOP - Система управления              ║")
        print("╚═══════════════════════════════════════════════════════╝")
        print("")
        print("1. Показать все предметы")
        print("2. Показать только предметы с ценами")
        print("3. Поиск предмета")
        print("4. Детальная информация о предмете")
        print("5. Выход")
        print("")
        io.write("Выберите опцию (1-5): ")
        
        local choice = io.read()
        term.clear()
        
        if choice == "1" then
            listAllItems()
            print("Нажмите Enter для продолжения...")
            io.read()
        elseif choice == "2" then
            listItemsWithPrices()
            print("Нажмите Enter для продолжения...")
            io.read()
        elseif choice == "3" then
            io.write("Введите название предмета для поиска: ")
            local query = io.read()
            if query and query ~= "" then
                searchItem(query)
            end
            print("Нажмите Enter для продолжения...")
            io.read()
        elseif choice == "4" then
            io.write("Введите название предмета: ")
            local query = io.read()
            if query and query ~= "" then
                getItemDetails(query)
            end
            print("Нажмите Enter для продолжения...")
            io.read()
        elseif choice == "5" then
            print("До свидания!")
            break
        else
            print("Неверный выбор. Попробуйте снова.")
            os.sleep(1)
        end
    end
end

-- Запуск программы
showMenu()
