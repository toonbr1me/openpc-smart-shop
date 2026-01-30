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
local shell = require("shell")

-- Путь установки программы (фиксированный)
local INSTALL_DIR = "/home/ore-exchange/"

-- Добавляем путь к библиотекам в package.path
package.path = package.path .. ";" .. INSTALL_DIR .. "?.lua;" .. INSTALL_DIR .. "lib/?.lua"

-- Сбрасываем кеш модулей
package.loaded["me_api"] = nil
package.loaded["cell_api"] = nil
package.loaded["gui"] = nil
package.loaded["config"] = nil

-- Безопасный require с понятной ошибкой
local function safeRequire(name)
    local ok, mod = pcall(require, name)
    if not ok then
        error("Не удалось загрузить '" .. name .. "': " .. tostring(mod))
    end
    return mod
end

-- Меняем рабочую директорию, чтобы относительные пути работали
pcall(shell.setWorkingDirectory, INSTALL_DIR)

local meAPI = safeRequire("me_api")
local cellAPI = safeRequire("cell_api")
local gui = safeRequire("gui")
local config = safeRequire("config")

-- ═══════════════════════════════════════════════════════════════
-- ОСНОВНЫЕ ПЕРЕМЕННЫЕ
-- ═══════════════════════════════════════════════════════════════

local running = true
local bufferSide = config.transposer and config.transposer.bufferSide or sides.front   -- сундук игрока
local driveSide = config.transposer and config.transposer.driveSide or sides.back      -- ME-привод (ME Drive)
local trashSide = config.transposer and config.transposer.trashSide or sides.left     -- куда списываем руду
local supplySide = config.transposer and config.transposer.supplySide or nil          -- опционально: сундук с блоками/слитками
local bufferSlot = config.transposer and config.transposer.bufferSlot or 1
local driveSlot = config.transposer and config.transposer.driveSlot or 1

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

-- Проверить доступность выходов: если нет в сети, но есть сундук supplySide — попробуем подтянуть
local function checkOutputsAvailability(ores)
    local available = {}
    local issues = {}

    for oreName, ore in pairs(ores) do
        local exchanges = math.floor(ore.total / ore.rate.input)
        if exchanges > 0 then
            local output = selectedOutputs[oreName] or ore.rate.outputs[1]
            local needed = exchanges * output.amount

            -- Проверяем в сети
            local hasEnough, inStock = meAPI.hasItem(output.item, needed, output.damage)

            -- Если не хватает и указан сундук-поставщик, пробуем импортировать
            if (not hasEnough) and supplySide then
                meAPI.importItem(supplySide)
                hasEnough, inStock = meAPI.hasItem(output.item, needed, output.damage)
            end

            available[oreName] = {
                output = output,
                needed = needed,
                inStock = inStock,
                hasEnough = hasEnough
            }

            if not hasEnough then
                table.insert(issues, string.format("%s: нужно %d, есть %d", output.label, needed, inStock))
            end
        end
    end

    return available, issues
end

-- Выполнить обмен: списать руду в trashSide, выдать блоки/слитки (остаются в сети → в ячейке)
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

                log(string.format("Обмен: %s x%d → %s x%d", oreName, oreToTake, output.item, itemsToGive))

                -- Шаг 1: списываем руду из сети в мусор
                meAPI.exportItem(trashSide, oreName, oreToTake, ore.damage or 0)

                -- Шаг 2: выдаём блоки/слитки (останутся в сети, т.е. в ячейке)
                meAPI.exportItem(bufferSide, output.item, 0) -- no-op to touch
                -- ничего не делаем: предметы уже в сети, остаются в ячейке

                table.insert(results, {
                    inputLabel = ore.label or oreName,
                    inputAmount = oreToTake,
                    outputLabel = output.label,
                    outputAmount = itemsToGive
                })
                totalInput = totalInput + oreToTake
                totalOutput = totalOutput + itemsToGive
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
        if #ore.rate.outputs > 1 then
            local exchanges = math.floor(ore.total / ore.rate.input)
            if exchanges > 0 then
                gui.clear()
                gui.drawHeader("⚙ ВЫБОР ВЫХОДА")

                local buttons = { gui.drawButton(3, 5, 20, 3, "Вариант 1"), gui.drawButton(3, 9, 20, 3, "Вариант 2") }

                local tButtons, _ = gui.drawOutputSelection(ore, 5)
                buttons = tButtons

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
                        selectedOutputs[oreName] = ore.rate.outputs[1]
                        goto nextOre
                    end
                end
                ::nextOre::
            end
        else
            selectedOutputs[oreName] = ore.rate.outputs[1]
        end
    end

    return selectedOutputs
end

-- ═══════════════════════════════════════════════════════════════
-- ГЛАВНЫЙ ЦИКЛ ОБРАБОТКИ ЯЧЕЙКИ
-- ═══════════════════════════════════════════════════════════════

local function processCell()
    log("Обнаружена ячейка в буфере, начинаю обработку...")

    -- Проверяем наличие ячейки в буфере
    local bufferCell = cellAPI.getStackInSlot(bufferSide, bufferSlot)
    if not bufferCell then
        gui.showError("Не найдена переносная ячейка в буфере")
        sleep(3)
        return
    end

    -- Проверяем, что слот ME-привода свободен
    local driveCell = cellAPI.getStackInSlot(driveSide, driveSlot)
    if driveCell then
        gui.showError("Слот ME-привода занят! Освободите его.")
        sleep(5)
        return
    end

    -- Переносим ячейку из буфера в ME-привод
    local movedToDrive, movedCount = cellAPI.transferItem(bufferSide, driveSide, 1, bufferSlot, driveSlot)
    if not movedToDrive or movedCount == 0 then
        gui.showError("Не удалось вставить ячейку в ME-привод")
        sleep(5)
        return
    end

    log("Ячейка установлена в ME-привод, ожидаем доступ к сети...")
    sleep(1)

    local function returnCellToBuffer()
        local backOk, backCount = cellAPI.transferItem(driveSide, bufferSide, 1, driveSlot, bufferSlot)
        if not backOk or backCount == 0 then
            log("ВНИМАНИЕ: не удалось вернуть ячейку в буферный сундук!")
            gui.showError("Не удалось вернуть ячейку в буфер")
            sleep(5)
            return false
        end
        return true
    end

    -- Руды берём из ME сети (ячейка в приводе)
    local ores = {}
    local items = meAPI.getItems()
    if items then
        for _, item in pairs(items) do
            local rate = config.exchangeRates[item.name]
            if rate then
                ores[item.name] = {
                    name = item.name,
                    label = item.label,
                    total = item.size,
                    rate = rate,
                    damage = item.damage or 0
                }
            end
        end
    end

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
        returnCellToBuffer()
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
        returnCellToBuffer()
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
        returnCellToBuffer()
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

    -- Возвращаем ячейку в буфер
    if not returnCellToBuffer() then
        return
    end

    gui.centerText(gui.height - 2, "Заберите ячейку из буфера")

    -- Ждём пока игрок заберёт ячейку из буферного сундука
    while cellAPI.getStackInSlot(bufferSide, bufferSlot) do
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

        -- Проверяем наличие ячейки в буферном слоте
        while not cellAPI.getStackInSlot(bufferSide, bufferSlot) do
            sleep(0.5)

            -- Проверяем события (например Ctrl+C для выхода)
            local ev = event.pull(0.1)
            if ev == "interrupted" then
                running = false
                break
            end
        end
        
        if running and cellAPI.getStackInSlot(bufferSide, bufferSlot) then
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
