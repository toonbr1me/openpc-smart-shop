-- Быстрый поиск предметов с ценами в ME системе
-- Использование: price_search <название предмета>

local component = require("component")
local unicode = require("unicode")
local args = {...}

-- Функция для безопасного поиска ME компонента
local function findMEComponent()
    local meTypes = {"me_interface", "me_controller", "me_exportbus", "me_importbus"}
    
    for _, meType in ipairs(meTypes) do
        -- Используем component.list() для поиска
        local address = component.list(meType, true)()
        if address then
            return component.proxy(address)
        end
    end
    
    return nil
end

-- Проверка наличия ME компонента
local me = findMEComponent()

if not me then
    print("ОШИБКА: ME компонент не найден!")
    print("Убедитесь что Adapter подключен к ME Interface")
    return
end

-- Функция для парсинга цены из описания предмета
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

-- Функция для получения читаемого имени предмета
local function getItemName(itemData)
    return itemData.label or itemData.name or "Неизвестный предмет"
end

-- Основная логика
if #args == 0 then
    print("Использование: price_search <название предмета>")
    print("Пример: price_search алмаз")
    return
end

local searchQuery = table.concat(args, " ")
print("Поиск: '" .. searchQuery .. "'")
print("")

local items = me.getItemsInNetwork()

if not items then
    print("Не удалось получить список предметов")
    return
end

local found = false
local queryLower = unicode.lower(searchQuery)

for _, item in ipairs(items) do
    local name = getItemName(item)
    local nameLower = unicode.lower(name)
    
    if nameLower:find(queryLower, 1, true) then
        found = true
        local price = parsePrice(item)
        local size = item.size or 0
        
        if price then
            print(string.format("%s - %d шт. - %.2f$ (Всего: %.2f$)", 
                name, size, price, price * size))
        else
            print(string.format("%s - %d шт. - Цена не указана", name, size))
        end
    end
end

if not found then
    print("Предметы не найдены")
end
