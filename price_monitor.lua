-- Автоматический мониторинг изменений цен в ME системе
-- Использование: price_monitor [интервал_в_секундах]

local component = require("component")
local unicode = require("unicode")
local event = require("event")
local term = require("term")
local args = {...}

-- Функция для безопасного поиска ME компонента
local function findMEComponent()
    local meTypes = {"me_interface", "me_controller", "me_exportbus", "me_importbus"}
    
    for _, meType in ipairs(meTypes) do
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
    return
end

local interval = tonumber(args[1]) or 60  -- По умолчанию 60 секунд

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

-- Функция для получения snapshot текущего состояния
local function getSnapshot()
    local items = me.getItemsInNetwork()
    if not items then
        return nil
    end
    
    local snapshot = {}
    local totalValue = 0
    local itemsWithPrice = 0
    
    for _, item in ipairs(items) do
        local itemID = item.name or "unknown"
        local price = parsePrice(item)
        local size = item.size or 0
        
        snapshot[itemID] = {
            name = getItemName(item),
            price = price,
            quantity = size
        }
        
        if price then
            totalValue = totalValue + (price * size)
            itemsWithPrice = itemsWithPrice + 1
        end
    end
    
    return {
        items = snapshot,
        totalValue = totalValue,
        itemsWithPrice = itemsWithPrice,
        totalItems = #items
    }
end

-- Функция для сравнения snapshots
local function compareSnapshots(old, new)
    if not old or not new then
        return {}
    end
    
    local changes = {
        added = {},
        removed = {},
        quantityChanged = {},
        priceChanged = {}
    }
    
    -- Проверяем новые и измененные предметы
    for id, newItem in pairs(new.items) do
        local oldItem = old.items[id]
        
        if not oldItem then
            table.insert(changes.added, {id = id, item = newItem})
        else
            if newItem.quantity ~= oldItem.quantity then
                table.insert(changes.quantityChanged, {
                    id = id,
                    item = newItem,
                    oldQuantity = oldItem.quantity,
                    newQuantity = newItem.quantity
                })
            end
            
            if newItem.price and oldItem.price and newItem.price ~= oldItem.price then
                table.insert(changes.priceChanged, {
                    id = id,
                    item = newItem,
                    oldPrice = oldItem.price,
                    newPrice = newItem.price
                })
            end
        end
    end
    
    -- Проверяем удаленные предметы
    for id, oldItem in pairs(old.items) do
        if not new.items[id] then
            table.insert(changes.removed, {id = id, item = oldItem})
        end
    end
    
    return changes
end

-- Функция для отображения изменений
local function displayChanges(changes, oldSnapshot, newSnapshot)
    term.clear()
    print("╔═══════════════════════════════════════════════════════════════════════╗")
    print("║                    ME МОНИТОРИНГ - " .. os.date("%H:%M:%S") .. "                         ║")
    print("╚═══════════════════════════════════════════════════════════════════════╝")
    print("")
    
    -- Статистика
    print(string.format("Всего предметов: %d | С ценами: %d | Общая стоимость: %.2f$",
        newSnapshot.totalItems, newSnapshot.itemsWithPrice, newSnapshot.totalValue))
    
    if oldSnapshot then
        local valueDiff = newSnapshot.totalValue - oldSnapshot.totalValue
        if valueDiff > 0 then
            print(string.format("Изменение стоимости: +%.2f$ ↑", valueDiff))
        elseif valueDiff < 0 then
            print(string.format("Изменение стоимости: %.2f$ ↓", valueDiff))
        end
    end
    
    print("")
    
    -- Изменения цен
    if #changes.priceChanged > 0 then
        print("━━━ ИЗМЕНЕНИЯ ЦЕН ━━━")
        for _, change in ipairs(changes.priceChanged) do
            local diff = change.newPrice - change.oldPrice
            local arrow = diff > 0 and "↑" or "↓"
            print(string.format("  %s: %.2f$ → %.2f$ (%+.2f$ %s)",
                change.item.name, change.oldPrice, change.newPrice, diff, arrow))
        end
        print("")
    end
    
    -- Добавленные предметы
    if #changes.added > 0 then
        print("━━━ НОВЫЕ ПРЕДМЕТЫ ━━━")
        for _, change in ipairs(changes.added) do
            local priceStr = change.item.price and string.format("%.2f$", change.item.price) or "N/A"
            print(string.format("  + %s (%d шт., %s)",
                change.item.name, change.item.quantity, priceStr))
        end
        print("")
    end
    
    -- Удаленные предметы
    if #changes.removed > 0 then
        print("━━━ ПРОДАННЫЕ/УДАЛЕННЫЕ ПРЕДМЕТЫ ━━━")
        for _, change in ipairs(changes.removed) do
            local priceStr = change.item.price and string.format("%.2f$", change.item.price) or "N/A"
            print(string.format("  - %s (было %d шт., %s)",
                change.item.name, change.item.quantity, priceStr))
        end
        print("")
    end
    
    -- Изменения количества (показываем только самые значительные)
    if #changes.quantityChanged > 0 then
        print("━━━ ИЗМЕНЕНИЯ КОЛИЧЕСТВА ━━━")
        for i = 1, math.min(5, #changes.quantityChanged) do
            local change = changes.quantityChanged[i]
            local diff = change.newQuantity - change.oldQuantity
            local arrow = diff > 0 and "↑" or "↓"
            print(string.format("  %s: %d → %d (%+d %s)",
                change.item.name, change.oldQuantity, change.newQuantity, diff, arrow))
        end
        if #changes.quantityChanged > 5 then
            print(string.format("  ... и еще %d изменений", #changes.quantityChanged - 5))
        end
        print("")
    end
    
    print("Следующая проверка через " .. interval .. " сек. Нажмите Ctrl+C для выхода")
    print("═══════════════════════════════════════════════════════════════════════")
end

-- Основной цикл
print("Запуск мониторинга ME системы...")
print("Интервал: " .. interval .. " секунд")
print("Нажмите Ctrl+C для остановки")
print("")

local oldSnapshot = nil
local running = true

-- Обработчик прерывания
event.listen("interrupted", function()
    running = false
end)

while running do
    local newSnapshot = getSnapshot()
    
    if newSnapshot then
        local changes = compareSnapshots(oldSnapshot, newSnapshot)
        displayChanges(changes, oldSnapshot, newSnapshot)
        oldSnapshot = newSnapshot
    else
        print("Ошибка получения данных из ME системы")
    end
    
    -- Ждем интервал или прерывание
    local startTime = os.time()
    while running and (os.time() - startTime) < interval do
        os.sleep(1)
    end
end

print("\nМониторинг остановлен")
