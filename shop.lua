-- OpenComputers Smart Shop System
-- Автор: AI Assistant
-- Описание: Система торговли с ME интеграцией

local component = require("component")
local event = require("event")
local term = require("term")
local serialization = require("serialization")
local unicode = require("unicode")
local sides = require("sides")

-- ============================================
-- КОНФИГУРАЦИЯ И ИНИЦИАЛИЗАЦИЯ
-- ============================================

local config = {
    -- Адреса компонентов (будут определены автоматически)
    meController = nil,
    moneyChest = nil,     -- Сундук для приема денег
    outputChest = nil,     -- Сундук для выдачи товаров
    
    -- Настройки валюты
    moneyItem = "contenttweaker:money",
    moneyName = "Деньги",
    
    -- Настройки отображения
    colors = {
        bg = 0x000000,
        header = 0x4B4B4B,
        primary = 0x2196F3,
        success = 0x4CAF50,
        error = 0xF44336,
        text = 0xFFFFFF,
        secondary = 0xBBBBBB
    }
}

local gpu = component.gpu
local me = nil
local transposerMoney = nil
local transposerOutput = nil

-- Баланс пользователя (в памяти)
local userBalance = 0

-- ============================================
-- УТИЛИТЫ И ОТЛАДКА
-- ============================================

local function debug(message, level)
    level = level or "INFO"
    local colors = {
        INFO = 0xFFFFFF,
        SUCCESS = 0x4CAF50,
        ERROR = 0xF44336,
        WARN = 0xFFEB3B
    }
    
    local oldFg = gpu.getForeground()
    gpu.setForeground(colors[level] or 0xFFFFFF)
    print("[" .. level .. "] " .. message)
    gpu.setForeground(oldFg)
end

local function centerText(y, text, color)
    local w, h = gpu.getResolution()
    local x = math.floor((w - unicode.len(text)) / 2)
    gpu.setForeground(color or config.colors.text)
    gpu.set(x, y, text)
end

local function drawBox(x, y, width, height, color)
    gpu.setBackground(color)
    gpu.fill(x, y, width, height, " ")
end

local function drawHeader()
    local w, h = gpu.getResolution()
    drawBox(1, 1, w, 3, config.colors.header)
    gpu.setBackground(config.colors.header)
    centerText(2, "=== SMART SHOP ===", config.colors.primary)
end

local function drawBalance()
    local w, h = gpu.getResolution()
    gpu.setBackground(config.colors.bg)
    gpu.setForeground(config.colors.success)
    gpu.set(2, 4, "Баланс: " .. string.format("%.2f", userBalance) .. "$")
end

-- ============================================
-- ИНИЦИАЛИЗАЦИЯ КОМПОНЕНТОВ
-- ============================================

local function initComponents()
    debug("Инициализация компонентов...")
    
    -- ME Controller
    if component.isAvailable("me_controller") then
        me = component.me_controller
        config.meController = me.address
        debug("✓ ME Controller найден: " .. me.address:sub(1, 8), "SUCCESS")
    else
        debug("✗ ME Controller не найден!", "ERROR")
        return false
    end
    
    -- Transposers для сундуков
    local transposers = {}
    for address in component.list("transposer") do
        table.insert(transposers, component.proxy(address))
        debug("Найден Transposer: " .. address:sub(1, 8), "INFO")
    end
    
    if #transposers >= 2 then
        transposerMoney = transposers[1]
        transposerOutput = transposers[2]
        config.moneyChest = transposerMoney.address
        config.outputChest = transposerOutput.address
        debug("✓ Transposers настроены", "SUCCESS")
        debug("  Сундук для денег: " .. transposerMoney.address:sub(1, 8), "INFO")
        debug("  Сундук выдачи: " .. transposerOutput.address:sub(1, 8), "INFO")
    else
        debug("✗ Нужно минимум 2 Transposer!", "ERROR")
        return false
    end
    
    -- GPU
    if component.isAvailable("gpu") then
        gpu.setResolution(80, 25)
        gpu.setBackground(config.colors.bg)
        gpu.setForeground(config.colors.text)
        term.clear()
        debug("✓ GPU настроен (80x25)", "SUCCESS")
    end
    
    return true
end

-- ============================================
-- РАБОТА С ДЕНЬГАМИ
-- ============================================

local function countMoneyInChest()
    debug("Проверка денег в сундуке...")
    local total = 0
    
    -- Проверяем все слоты сундука (сторона 3 = верх transposer'а)
    for slot = 1, transposerMoney.getInventorySize(sides.up) do
        local item = transposerMoney.getStackInSlot(sides.up, slot)
        if item and item.name == config.moneyItem then
            -- Проверяем количество (может быть дробное)
            local amount = item.size or 1
            total = total + amount
            debug("  Слот " .. slot .. ": " .. amount .. " денег", "INFO")
        end
    end
    
    return total
end

local function transferMoneyToME()
    debug("Перенос денег в ME систему...")
    local totalTransferred = 0
    
    for slot = 1, transposerMoney.getInventorySize(sides.up) do
        local item = transposerMoney.getStackInSlot(sides.up, slot)
        if item and item.name == config.moneyItem then
            -- Переносим в ME (сторона может отличаться!)
            local transferred = transposerMoney.transferItem(sides.up, sides.down, item.size, slot)
            if transferred > 0 then
                totalTransferred = totalTransferred + transferred
                debug("  Перенесено " .. transferred .. " из слота " .. slot, "SUCCESS")
            end
        end
    end
    
    return totalTransferred
end

local function depositMoney()
    gpu.setBackground(config.colors.bg)
    term.clear()
    drawHeader()
    
    gpu.setForeground(config.colors.text)
    gpu.set(2, 6, "Положите деньги в сундук и нажмите ENTER")
    gpu.set(2, 7, "Или нажмите ESC для отмены")
    
    while true do
        local eventType, _, char, code = event.pull()
        
        if eventType == "key_down" then
            if code == 28 then -- Enter
                local money = countMoneyInChest()
                if money > 0 then
                    local transferred = transferMoneyToME()
                    userBalance = userBalance + transferred
                    
                    debug("Пополнение баланса на " .. transferred .. "$", "SUCCESS")
                    
                    gpu.setForeground(config.colors.success)
                    gpu.set(2, 9, "✓ Баланс пополнен на " .. string.format("%.2f", transferred) .. "$")
                    gpu.set(2, 10, "Текущий баланс: " .. string.format("%.2f", userBalance) .. "$")
                    os.sleep(3)
                    return true
                else
                    gpu.setForeground(config.colors.error)
                    gpu.set(2, 9, "✗ Деньги не найдены в сундуке!")
                    os.sleep(2)
                    return false
                end
            elseif code == 1 then -- Esc
                return false
            end
        end
    end
end

-- ============================================
-- РАБОТА С ME И ПРЕДМЕТАМИ
-- ============================================

local function parsePrice(lore)
    if not lore then return nil end
    
    debug("  Попытка парсинга цены из lore...", "INFO")
    
    -- Попытка 1: "Минимальная цена: 15.0$"
    for _, line in ipairs(lore) do
        local price = string.match(line, "Минимальная цена:%s*([%d%.]+)")
        if price then
            debug("    ✓ Найдено через 'Минимальная цена': " .. price, "SUCCESS")
            return tonumber(price)
        end
    end
    
    -- Попытка 2: "Цена: 15.0$" или "Price: 15.0$"
    for _, line in ipairs(lore) do
        local price = string.match(line, "[Цц]ена:%s*([%d%.]+)")
        if not price then
            price = string.match(line, "[Pp]rice:%s*([%d%.]+)")
        end
        if price then
            debug("    ✓ Найдено через 'Цена/Price': " .. price, "SUCCESS")
            return tonumber(price)
        end
    end
    
    -- Попытка 3: "15.0$" или "$15.0" в строке
    for _, line in ipairs(lore) do
        local price = string.match(line, "([%d%.]+)%$")
        if not price then
            price = string.match(line, "%$([%d%.]+)")
        end
        if price then
            debug("    ✓ Найдено число с $: " .. price, "SUCCESS")
            return tonumber(price)
        end
    end
    
    -- Попытка 4: Просто число с точкой "15.0" или "15.50"
    for _, line in ipairs(lore) do
        local price = string.match(line, "([%d]+%.[%d]+)")
        if price then
            debug("    ✓ Найдено дробное число: " .. price, "SUCCESS")
            return tonumber(price)
        end
    end
    
    debug("    ✗ Цена не найдена в lore", "WARN")
    return nil
end

local function getDetailedItemInfo(itemStack)
    debug("  Получение детальной информации о предмете...", "INFO")
    
    local info = {
        name = itemStack.name,
        label = itemStack.label or itemStack.name,
        size = itemStack.size or 0,
        damage = itemStack.damage or 0,
        maxSize = itemStack.maxSize or 64,
        hasTag = itemStack.hasTag or false,
        price = nil,
        lore = {}
    }
    
    -- Попытка получить NBT данные
    if itemStack.hasTag then
        debug("    Предмет имеет NBT данные", "INFO")
        
        -- Попытка получить display.Lore
        if itemStack.tag and itemStack.tag.display then
            if itemStack.tag.display.Lore then
                debug("    Найден tag.display.Lore", "SUCCESS")
                info.lore = itemStack.tag.display.Lore
            end
            if itemStack.tag.display.Name then
                debug("    Найден tag.display.Name: " .. itemStack.tag.display.Name, "INFO")
                info.label = itemStack.tag.display.Name
            end
        end
    end
    
    -- Пытаемся парсить цену из lore
    if #info.lore > 0 then
        debug("    Lore содержит " .. #info.lore .. " строк:", "INFO")
        for i, line in ipairs(info.lore) do
            debug("      [" .. i .. "] " .. line, "INFO")
        end
        info.price = parsePrice(info.lore)
    else
        debug("    Lore пуст или недоступен", "WARN")
    end
    
    return info
end

local function getItemsFromME()
    debug("Получение списка предметов из ME...", "INFO")
    local items = {}
    
    if not me then
        debug("ME Controller недоступен!", "ERROR")
        return items
    end
    
    local meItems = me.getItemsInNetwork()
    
    -- Проверка типа возвращаемого значения
    if not meItems or type(meItems) ~= "table" then
        debug("Ошибка: getItemsInNetwork() вернул " .. type(meItems), "ERROR")
        debug("Попробуйте альтернативный метод...", "WARN")
        
        -- Попытка использовать getAvailableItems() как альтернативу
        if me.getAvailableItems then
            meItems = me.getAvailableItems()
            debug("Используется getAvailableItems() вместо getItemsInNetwork()", "INFO")
        end
        
        if not meItems or type(meItems) ~= "table" then
            debug("ME система не возвращает список предметов!", "ERROR")
            debug("Убедитесь что ME система включена и содержит предметы", "ERROR")
            return items
        end
    end
    
    debug("Найдено предметов в ME: " .. #meItems, "INFO")
    debug("")
    debug("=== ДЕТАЛЬНЫЙ АНАЛИЗ ПРЕДМЕТОВ ===", "INFO")
    
    local pricesFound = 0
    local pricesMissing = 0
    
    for index, item in ipairs(meItems) do
        debug("")
        debug("[" .. index .. "/" .. #meItems .. "] Анализ: " .. (item.label or item.name), "INFO")
        debug("  ID: " .. item.name, "INFO")
        debug("  Количество: " .. (item.size or 0), "INFO")
        debug("  Damage: " .. (item.damage or 0), "INFO")
        debug("  hasTag: " .. tostring(item.hasTag or false), "INFO")
        
        -- Получаем детальную информацию
        local itemInfo = getDetailedItemInfo(item)
        
        if itemInfo.price then
            pricesFound = pricesFound + 1
            debug("  💰 ЦЕНА НАЙДЕНА: " .. string.format("%.2f", itemInfo.price) .. "$", "SUCCESS")
        else
            pricesMissing = pricesMissing + 1
            -- Используем дефолтную цену для теста
            itemInfo.price = 10.0
            debug("  ⚠ Цена не найдена, используем дефолт: 10.0$", "WARN")
        end
        
        table.insert(items, itemInfo)
        
        -- Ограничиваем детальный анализ первыми 5 предметами для экономии
        if index >= 5 then
            debug("")
            debug("... (остальные " .. (#meItems - 5) .. " предметов обрабатываются без детального лога)", "INFO")
            
            -- Обрабатываем остальные быстро
            for i = 6, #meItems do
                local quickItem = meItems[i]
                local quickInfo = getDetailedItemInfo(quickItem)
                if not quickInfo.price then
                    quickInfo.price = 10.0
                    pricesMissing = pricesMissing + 1
                else
                    pricesFound = pricesFound + 1
                end
                table.insert(items, quickInfo)
            end
            break
        end
    end
    
    debug("")
    debug("=== ИТОГИ АНАЛИЗА ===", "INFO")
    debug("Всего предметов: " .. #items, "INFO")
    debug("Цены найдены: " .. pricesFound, "SUCCESS")
    debug("Цены не найдены: " .. pricesMissing, "WARN")
    if pricesFound > 0 then
        debug("✓ Парсинг цен работает! (" .. math.floor(pricesFound / #items * 100) .. "%)", "SUCCESS")
    else
        debug("✗ Парсинг цен НЕ работает. Используйте конфиг файл!", "ERROR")
    end
    debug("")
    
    return items
end

local function searchItems(query, items)
    if query == "" then
        return items
    end
    
    local results = {}
    query = unicode.lower(query)
    
    -- Умный поиск с приоритетами
    local exactMatches = {}      -- Точное совпадение
    local startMatches = {}      -- Начинается с
    local containsMatches = {}   -- Содержит
    local wordMatches = {}       -- Совпадает по словам
    
    for _, item in ipairs(items) do
        local label = unicode.lower(item.label)
        local name = unicode.lower(item.name)
        
        -- 1. Точное совпадение (высший приоритет)
        if label == query or name == query then
            table.insert(exactMatches, item)
        
        -- 2. Начинается с запроса
        elseif unicode.sub(label, 1, unicode.len(query)) == query or 
               unicode.sub(name, 1, unicode.len(query)) == query then
            table.insert(startMatches, item)
        
        -- 3. Содержит запрос
        elseif unicode.find(label, query, 1, true) or 
               unicode.find(name, query, 1, true) then
            table.insert(containsMatches, item)
        
        -- 4. Поиск по отдельным словам
        else
            local words = {}
            for word in query:gmatch("%S+") do
                table.insert(words, word)
            end
            
            local allWordsFound = true
            for _, word in ipairs(words) do
                if not unicode.find(label, word, 1, true) and 
                   not unicode.find(name, word, 1, true) then
                    allWordsFound = false
                    break
                end
            end
            
            if allWordsFound and #words > 0 then
                table.insert(wordMatches, item)
            end
        end
    end
    
    -- Объединяем результаты по приоритету
    for _, item in ipairs(exactMatches) do
        table.insert(results, item)
    end
    for _, item in ipairs(startMatches) do
        table.insert(results, item)
    end
    for _, item in ipairs(containsMatches) do
        table.insert(results, item)
    end
    for _, item in ipairs(wordMatches) do
        table.insert(results, item)
    end
    
    return results
end

local function craftAndTransferItem(itemName, damage, amount)
    debug("Крафт предмета: " .. itemName .. " x" .. amount, "INFO")
    
    -- Получаем крафтабельные предметы
    local craftables = me.getCraftables()
    
    for _, craftable in pairs(craftables) do
        local itemStack = craftable.getItemStack()
        if itemStack.name == itemName and (itemStack.damage or 0) == damage then
            debug("Найден рецепт крафта!", "SUCCESS")
            
            -- Запускаем крафт
            local crafting = craftable.request(amount)
            
            if crafting then
                debug("Крафт запущен, ожидание...", "INFO")
                
                -- Ждем завершения крафта
                while not crafting.isDone() do
                    os.sleep(0.5)
                end
                
                if crafting.isCanceled() then
                    debug("Крафт отменен!", "ERROR")
                    return false
                end
                
                debug("Крафт завершен!", "SUCCESS")
                
                -- Экспортируем в сундук выдачи
                os.sleep(1) -- Даем время ME системе
                
                local exported = me.exportItem({
                    name = itemName,
                    damage = damage
                }, sides.down, amount)
                
                if exported > 0 then
                    debug("Экспортировано: " .. exported .. " шт.", "SUCCESS")
                    return true
                else
                    debug("Ошибка экспорта!", "ERROR")
                    return false
                end
            end
        end
    end
    
    debug("Рецепт не найден, пробуем прямой экспорт...", "WARN")
    
    -- Если крафт не нужен, просто экспортируем
    local exported = me.exportItem({
        name = itemName,
        damage = damage
    }, sides.down, amount)
    
    if exported > 0 then
        debug("Экспортировано напрямую: " .. exported .. " шт.", "SUCCESS")
        return true
    end
    
    return false
end

-- ============================================
-- GUI И МЕНЮ
-- ============================================

local function drawItemList(items, startIndex, selectedIndex)
    local w, h = gpu.getResolution()
    local maxDisplay = 15
    
    gpu.setBackground(config.colors.bg)
    gpu.fill(1, 8, w, maxDisplay, " ")
    
    for i = 1, maxDisplay do
        local itemIndex = startIndex + i - 1
        if itemIndex <= #items then
            local item = items[itemIndex]
            local y = 7 + i
            
            if itemIndex == selectedIndex then
                gpu.setBackground(config.colors.primary)
            else
                gpu.setBackground(config.colors.bg)
            end
            
            -- Индикатор цены: ✓ если цена распознана, ? если дефолт
            local priceIndicator = (item.price and item.price ~= 10.0) and "✓" or "?"
            
            local displayText = string.format("%s %-38s %7s шт. %8.2f$", 
                priceIndicator,
                unicode.sub(item.label, 1, 38),
                tostring(item.size),
                item.price or 0)
            
            -- Цвет цены: зеленый если распознана, серый если дефолт
            gpu.set(2, y, priceIndicator)
            gpu.setForeground(config.colors.text)
            gpu.set(4, y, unicode.sub(item.label, 1, 38))
            gpu.set(43, y, string.format("%7s шт.", tostring(item.size)))
            
            if item.price and item.price ~= 10.0 then
                gpu.setForeground(config.colors.success)
            else
                gpu.setForeground(config.colors.secondary)
            end
            gpu.set(54, y, string.format("%8.2f$", item.price or 0))
        end
    end
    
    gpu.setBackground(config.colors.bg)
end

local function shopMenu()
    local items = getItemsFromME()
    local filteredItems = items
    local searchQuery = ""
    local selectedIndex = 1
    local startIndex = 1
    local maxDisplay = 15
    
    while true do
        term.clear()
        drawHeader()
        drawBalance()
        
        gpu.setBackground(config.colors.bg)
        gpu.setForeground(config.colors.text)
        gpu.set(2, 5, "Поиск: " .. searchQuery .. "_")
        
        -- Информация о результатах поиска
        if searchQuery ~= "" then
            gpu.setForeground(config.colors.secondary)
            gpu.set(40, 5, "(найдено: " .. #filteredItems .. ")")
        end
        
        gpu.set(2, 6, string.rep("-", 78))
        gpu.setForeground(config.colors.secondary)
        gpu.set(2, 7, "✓=цена найдена  ?=дефолт 10$")
        
        drawItemList(filteredItems, startIndex, selectedIndex)
        
        gpu.setForeground(config.colors.text)
        gpu.set(2, 24, "[↑↓] Выбор [ENTER] Купить [D] Пополнить [R] Обновить [ESC] Выход")
        
        local eventType, _, char, code = event.pull()
        
        if eventType == "key_down" then
            if code == 200 then -- Up
                if selectedIndex > 1 then
                    selectedIndex = selectedIndex - 1
                    if selectedIndex < startIndex then
                        startIndex = startIndex - 1
                    end
                end
            elseif code == 208 then -- Down
                if selectedIndex < #filteredItems then
                    selectedIndex = selectedIndex + 1
                    if selectedIndex >= startIndex + maxDisplay then
                        startIndex = startIndex + 1
                    end
                end
            elseif code == 28 then -- Enter
                if #filteredItems > 0 and selectedIndex <= #filteredItems then
                    local item = filteredItems[selectedIndex]
                    local price = item.price or 0
                    
                    if userBalance >= price then
                        gpu.setBackground(config.colors.bg)
                        gpu.set(2, 23, "Покупка " .. item.label .. "... ")
                        
                        if craftAndTransferItem(item.name, item.damage, 1) then
                            userBalance = userBalance - price
                            gpu.setForeground(config.colors.success)
                            gpu.set(2, 23, "✓ Куплено! Заберите из сундука. Баланс: " .. string.format("%.2f", userBalance) .. "$")
                        else
                            gpu.setForeground(config.colors.error)
                            gpu.set(2, 23, "✗ Ошибка крафта/выдачи предмета!")
                        end
                        os.sleep(3)
                    else
                        gpu.setForeground(config.colors.error)
                        gpu.set(2, 23, "✗ Недостаточно средств! Нужно: " .. string.format("%.2f", price) .. "$")
                        os.sleep(2)
                    end
                end
            elseif code == 32 then -- D - Deposit
                depositMoney()
            elseif code == 19 then -- R - Refresh
                items = getItemsFromME()
                filteredItems = searchItems(searchQuery, items)
                selectedIndex = 1
                startIndex = 1
            elseif code == 1 then -- ESC
                return
            elseif char > 0 then
                searchQuery = searchQuery .. unicode.char(char)
                filteredItems = searchItems(searchQuery, items)
                selectedIndex = 1
                startIndex = 1
            elseif code == 14 then -- Backspace
                searchQuery = unicode.sub(searchQuery, 1, -2)
                filteredItems = searchItems(searchQuery, items)
                selectedIndex = 1
                startIndex = 1
            end
        end
    end
end

-- ============================================
-- ГЛАВНАЯ ФУНКЦИЯ
-- ============================================

local function main()
    term.clear()
    print("========================================")
    print("    OpenComputers Smart Shop System")
    print("========================================")
    print("")
    
    if not initComponents() then
        print("")
        print("Ошибка инициализации!")
        print("Проверьте подключение компонентов.")
        return
    end
    
    print("")
    print("✓ Система готова к работе!")
    os.sleep(2)
    
    shopMenu()
    
    term.clear()
    print("Спасибо за покупки!")
end

-- Запуск
local success, err = pcall(main)
if not success then
    term.clear()
    print("КРИТИЧЕСКАЯ ОШИБКА:")
    print(err)
end
