-- ═══════════════════════════════════════════════════════════════
-- ОБМЕННИК РУДЫ НА БЛОКИ
-- Для OpenComputers + Applied Energistics 2
-- ═══════════════════════════════════════════════════════════════
-- 
-- Требуемые компоненты:
-- 1. Компьютер OpenComputers (уровень 2+)
-- 2. Транспозер (для работы с ячейкой игрока)
-- 3. Адаптер с ME Controller или ME Interface
-- 4. Монитор + GPU для интерфейса
-- 5. Сундук/инвентарь для ячейки игрока
--
-- Схема подключения:
-- [Игрок] → [Сундук] ← [Транспозер] → [ME Interface]
--                ↓
--         [Компьютер + Монитор]
--
-- ═══════════════════════════════════════════════════════════════

local component = require("component")
local event = require("event")
local sides = require("sides")
local os = require("os")

-- Загрузка модулей
package.loaded["lib.me_api"] = nil
package.loaded["lib.cell_api"] = nil
package.loaded["lib.gui"] = nil

local meAPI = require("lib.me_api")
local cellAPI = require("lib.cell_api")
local gui = require("lib.gui")
local config = require("config")

-- ═══════════════════════════════════════════════════════════════
-- ОСНОВНЫЕ ПЕРЕМЕННЫЕ
-- ═══════════════════════════════════════════════════════════════

local running = true
local cellSide = sides.front  -- Сторона где ячейка игрока
local meSide = sides.back     -- Сторона ME системы

-- Выбранные выходы для руд с альтернативами
local selectedOutputs = {}

-- ═══════════════════════════════════════════════════════════════
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ═══════════════════════════════════════════════════════════════

local function log(message)
    print("[" .. os.date("%H:%M:%S") .. "] " .. message)
end

local function sleep(seconds)
    os.sleep(seconds)
end

-- ═══════════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ
-- ═══════════════════════════════════════════════════════════════

local function initialize()
    log("Инициализация обменника руды...")
    
    -- Инициализация ME
    local success, err = meAPI.init()
    if not success then
        log("ОШИБКА ME: " .. tostring(err))
        return false
    end
    log("ME система подключена (" .. meAPI.type .. ")")
    
    -- Инициализация транспозера
    success, err = cellAPI.init()
    if not success then
        log("ОШИБКА Транспозер: " .. tostring(err))
        return false
    end
    log("Транспозер подключен")
    
    -- Инициализация GUI
    success, err = gui.init(config.monitor)
    if not success then
        log("ОШИБКА GUI: " .. tostring(err))
        return false
    end
    log("GUI инициализирован")
    
    log("Инициализация завершена успешно!")
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- ЛОГИКА ОБМЕНА
-- ═══════════════════════════════════════════════════════════════

-- Проверить доступность всех выходов в ME системе
local function checkOutputsAvailability(ores)
    local available = {}
    local issues = {}
    
    for oreName, ore in pairs(ores) do
        local exchanges = math.floor(ore.total / ore.rate.input)
        if exchanges > 0 then
            local output = selectedOutputs[oreName] or ore.rate.outputs[1]
            local needed = exchanges * output.amount
            local hasEnough, inStock = meAPI.hasItem(output.item, needed)
            
            available[oreName] = {
                output = output,
                needed = needed,
                inStock = inStock,
                hasEnough = hasEnough
            }
            
            if not hasEnough then
                table.insert(issues, string.format(
                    "%s: нужно %d, есть %d", 
                    output.label, needed, inStock
                ))
            end
        end
    end
    
    return available, issues
end

-- Выполнить обмен
local function performExchange(ores, available)
    local results = {}
    local totalInput = 0
    local totalOutput = 0
    
    for oreName, ore in pairs(ores) do
        if available[oreName] and available[oreName].hasEnough then
            local rate = ore.rate
            local output = available[oreName].output
            local exchanges = math.floor(ore.total / rate.input)
            
            if exchanges > 0 then
                local oreToTake = exchanges * rate.input
                local itemsToGive = exchanges * output.amount
                
                log(string.format("Обмен: %s x%d → %s x%d", 
                    oreName, oreToTake, output.item, itemsToGive))
                
                -- Импортируем руду из ячейки в ME (через промежуточный буфер или напрямую)
                -- Примечание: в реальной реализации может потребоваться сначала
                -- переместить руду в буферный сундук рядом с ME
                
                -- Для простоты предполагаем, что транспозер может передать напрямую в ME
                -- или используем промежуточный буфер
                
                -- Шаг 1: Забираем руду из ячейки
                local extracted = 0
                for _, slotInfo in ipairs(ore.slots) do
                    if extracted >= oreToTake then break end
                    local toExtract = math.min(slotInfo.size, oreToTake - extracted)
                    -- Перемещаем в буфер или ME
                    local success, count = cellAPI.transferItem(cellSide, meSide, toExtract, slotInfo.slot)
                    if success then
                        extracted = extracted + count
                    end
                end
                
                -- Шаг 2: Экспортируем блоки/слитки из ME в ячейку
                local exported = 0
                local success, count = meAPI.exportItem(cellSide, output.item, itemsToGive, output.damage or 0)
                if success then
                    exported = count
                end
                
                if exported > 0 then
                    table.insert(results, {
                        inputLabel = ore.label or oreName,
                        inputAmount = extracted,
                        outputLabel = output.label,
                        outputAmount = exported
                    })
                    totalInput = totalInput + extracted
                    totalOutput = totalOutput + exported
                end
            end
        end
    end
    
    return results, totalInput, totalOutput
end

-- ═══════════════════════════════════════════════════════════════
-- ПРОЦЕСС ВЫБОРА ВЫХОДОВ ДЛЯ РУД С АЛЬТЕРНАТИВАМИ
-- ═══════════════════════════════════════════════════════════════

local function selectOutputsForOres(ores)
    selectedOutputs = {}
    
    for oreName, ore in pairs(ores) do
        -- Если есть альтернативные выходы - показываем выбор
        if #ore.rate.outputs > 1 then
            local exchanges = math.floor(ore.total / ore.rate.input)
            if exchanges > 0 then
                gui.clear()
                gui.drawHeader("⚙ ВЫБОР ВЫХОДА")
                
                local buttons, _ = gui.drawOutputSelection(ore, 5)
                
                -- Ждём выбора
                while true do
                    local x, y = gui.waitForTouch(30)
                    if x and y then
                        for _, btn in ipairs(buttons) do
                            if gui.isButtonClicked(btn, x, y) then
                                selectedOutputs[oreName] = btn.output
                                log("Выбран выход для " .. oreName .. ": " .. btn.output.label)
                                goto nextOre
                            end
                        end
                    else
                        -- Таймаут - используем первый вариант
                        selectedOutputs[oreName] = ore.rate.outputs[1]
                        goto nextOre
                    end
                end
                ::nextOre::
            end
        else
            -- Только один выход - используем его
            selectedOutputs[oreName] = ore.rate.outputs[1]
        end
    end
    
    return selectedOutputs
end

-- ═══════════════════════════════════════════════════════════════
-- ГЛАВНЫЙ ЦИКЛ ОБРАБОТКИ ЯЧЕЙКИ
-- ═══════════════════════════════════════════════════════════════

local function processCell()
    log("Обнаружена ячейка, начинаю обработку...")
    
    -- Получаем информацию о ячейке
    local cellInfo = cellAPI.getCellInfo(cellSide)
    if not cellInfo then
        gui.showError("Не удалось прочитать ячейку!")
        sleep(3)
        return
    end
    
    log(string.format("Ячейка: %d/%d слотов, %d предметов", 
        cellInfo.usedSlots, cellInfo.slots, cellInfo.totalItems))
    
    -- Ищем руды
    local ores = cellAPI.findOres(cellSide, config.exchangeRates)
    
    if not next(ores) then
        gui.clear()
        gui.drawHeader("⚒ ОБМЕННИК РУДЫ ⚒")
        gui.showError("В ячейке нет руды для обмена!")
        gui.gpu.setForeground(0x888888)
        gui.centerText(gui.height - 4, "Поддерживаемые руды:")
        local y = gui.height - 3
        for oreName, _ in pairs(config.exchangeRates) do
            if y < gui.height then
                gui.gpu.set(5, y, "• " .. oreName)
                y = y + 1
            end
        end
        sleep(5)
        return
    end
    
    -- Показываем найденные руды
    gui.clear()
    gui.drawHeader("⚒ ОБМЕННИК РУДЫ ⚒")
    local oreList, nextY = gui.drawOreList(ores, 5)
    
    sleep(2)
    
    -- Выбор выходов для руд с альтернативами
    selectOutputsForOres(ores)
    
    -- Проверяем доступность в ME
    local available, issues = checkOutputsAvailability(ores)
    
    if #issues > 0 then
        gui.clear()
        gui.drawHeader("⚠ НЕДОСТАТОЧНО РЕСУРСОВ")
        local y = 5
        gui.gpu.setForeground(gui.colors.error)
        gui.gpu.set(3, y, "В ME системе недостаточно предметов:")
        y = y + 2
        for _, issue in ipairs(issues) do
            gui.gpu.set(5, y, "• " .. issue)
            y = y + 1
        end
        gui.gpu.setForeground(gui.colors.text)
        gui.centerText(gui.height - 2, "Заберите ячейку и попробуйте позже")
        sleep(10)
        return
    end
    
    -- Показываем подтверждение
    local confirmBtn, cancelBtn = gui.drawConfirmScreen(ores, selectedOutputs)
    
    -- Ждём подтверждения
    local confirmed = false
    local timeout = 30
    local startTime = os.time()
    
    while os.time() - startTime < timeout do
        local x, y = gui.waitForTouch(1)
        if x and y then
            if gui.isButtonClicked(confirmBtn, x, y) then
                confirmed = true
                break
            elseif gui.isButtonClicked(cancelBtn, x, y) then
                break
            end
        end
    end
    
    if not confirmed then
        gui.clear()
        gui.drawHeader("✗ ОТМЕНЕНО")
        gui.centerText(gui.height / 2, "Обмен отменён. Заберите ячейку.")
        sleep(5)
        return
    end
    
    -- Выполняем обмен
    gui.clear()
    gui.drawHeader("⏳ ОБМЕН В ПРОЦЕССЕ")
    gui.centerText(gui.height / 2, "Выполняется обмен, подождите...")
    
    local results, totalIn, totalOut = performExchange(ores, available)
    
    if #results > 0 then
        gui.drawExchangeResult(results, totalIn, totalOut)
        log(string.format("Обмен завершён: %d руды → %d предметов", totalIn, totalOut))
    else
        gui.clear()
        gui.drawHeader("⚠ ОШИБКА")
        gui.showError("Не удалось выполнить обмен!")
    end
    
    -- Ждём пока игрок заберёт ячейку
    while cellAPI.isCellPresent(cellSide) do
        sleep(1)
    end
    
    log("Ячейка забрана")
end

-- ═══════════════════════════════════════════════════════════════
-- ГЛАВНЫЙ ЦИКЛ
-- ═══════════════════════════════════════════════════════════════

local function mainLoop()
    log("Запуск главного цикла...")
    
    while running do
        -- Показываем экран ожидания
        gui.drawWaitingScreen()
        
        -- Проверяем наличие ячейки
        while not cellAPI.isCellPresent(cellSide) do
            sleep(0.5)
            
            -- Проверяем события (например Ctrl+C для выхода)
            local ev = event.pull(0.1)
            if ev == "interrupted" then
                running = false
                break
            end
        end
        
        if running and cellAPI.isCellPresent(cellSide) then
            processCell()
        end
    end
    
    gui.clear()
    log("Программа завершена")
end

-- ═══════════════════════════════════════════════════════════════
-- ТОЧКА ВХОДА
-- ═══════════════════════════════════════════════════════════════

local function main()
    print("═══════════════════════════════════════════════")
    print("     ОБМЕННИК РУДЫ НА БЛОКИ v1.0")
    print("     OpenComputers + Applied Energistics 2")
    print("═══════════════════════════════════════════════")
    print()
    
    if not initialize() then
        print("Ошибка инициализации! Проверьте подключение компонентов.")
        return
    end
    
    print()
    print("Нажмите Ctrl+C для остановки")
    print()
    
    -- Обработчик прерывания
    event.listen("interrupted", function()
        running = false
    end)
    
    mainLoop()
end

-- Запуск
main()
