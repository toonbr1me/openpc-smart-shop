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

-- Загружаем модуль парсинга цен (опционально)
local priceParser = nil
local hasPriceParser, parserModule = pcall(require, "price-parser")
if hasPriceParser then
    priceParser = parserModule
    print("✓ Модуль парсинга цен из NBT загружен")
end

-- Загружаем конфиг с ценами (fallback если парсинг недоступен)
local hasConfig, priceConfig = pcall(require, "config")
if not hasConfig and not hasPriceParser then
    print("КРИТИЧЕСКАЯ ОШИБКА!")
    print("Ни config.lua, ни price-parser.lua не найдены!")
    print("")
    print("Нужен хотя бы один источник цен:")
    print("1. config.lua - ручные цены (всегда работает)")
    print("2. price-parser.lua - парсинг из Lore (требует Database)")
    print("")
    print("Создайте /home/config.lua по примеру test-config.lua")
    print("")
    os.exit(1)
end

if hasConfig then
    print("✓ Конфигурационный файл с ценами загружен")
end

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

local function getItemsFromME()
    debug("Получение списка предметов из ME...", "INFO")
    local items = {}
    
    if not me then
        debug("ME Controller недоступен!", "ERROR")
        return items
    end
    
    -- По офф. документации: getItemsInNetwork() без параметров
    local success, meItems = pcall(function() return me.getItemsInNetwork() end)
    
    if not success then
        debug("Ошибка вызова getItemsInNetwork(): " .. tostring(meItems), "ERROR")
        return items
    end
    
    if type(meItems) ~= "table" then
        debug("getItemsInNetwork() вернул " .. type(meItems) .. " вместо table", "ERROR")
        debug("Возможно ME система пустая или нет энергии", "WARN")
        return items
    end
    
    debug("Найдено предметов в ME: " .. #meItems, "INFO")
    
    if #meItems == 0 then
        debug("ME система пустая! Положите предметы в систему.", "WARN")
        return items
    end
    
    -- Обрабатываем предметы и получаем цены из конфига
    for _, item in ipairs(meItems) do
        local price = priceConfig.getPrice(item.name, item.damage or 0)
        
        table.insert(items, {
            name = item.name,
            label = item.label or item.name,
            size = item.size or 0,
            damage = item.damage or 0,
            maxSize = item.maxSize or 64,
            hasTag = item.hasTag or false,
            price = price
        })
    end
    
    debug("Обработано " .. #items .. " предметов", "SUCCESS")
    debug("Все цены получены из config.lua", "INFO")
    
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
            
            local displayText = string.format("%-40s %8s шт. %8.2f$", 
                unicode.sub(item.label, 1, 40),
                tostring(item.size),
                item.price or 0)
            
            gpu.setForeground(config.colors.text)
            gpu.set(2, y, displayText)
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
