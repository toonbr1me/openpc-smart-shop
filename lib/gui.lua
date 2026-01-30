-- GUI модуль для монитора
-- Отображает интерфейс выбора и информацию об обмене

local component = require("component")
local event = require("event")
local unicode = require("unicode")

local gui = {}

-- Инициализация GPU и экрана
function gui.init(config)
    if not component.isAvailable("gpu") then
        return false, "GPU не найден!"
    end
    
    gui.gpu = component.gpu
    gui.config = config or {}
    gui.colors = gui.config.colors or {
        background = 0x1E1E1E,
        header = 0x2D5A27,
        text = 0xFFFFFF,
        highlight = 0x4A90D9,
        success = 0x27AE60,
        error = 0xE74C3C,
        button = 0x3498DB,
        buttonHover = 0x2980B9
    }
    
    -- Получаем размер экрана
    gui.width, gui.height = gui.gpu.getResolution()
    
    return true
end

-- Очистка экрана
function gui.clear()
    gui.gpu.setBackground(gui.colors.background)
    gui.gpu.fill(1, 1, gui.width, gui.height, " ")
end

-- Нарисовать текст по центру
function gui.centerText(y, text, color)
    color = color or gui.colors.text
    gui.gpu.setForeground(color)
    local x = math.floor((gui.width - unicode.len(text)) / 2) + 1
    gui.gpu.set(x, y, text)
end

-- Нарисовать заголовок
function gui.drawHeader(title)
    gui.gpu.setBackground(gui.colors.header)
    gui.gpu.fill(1, 1, gui.width, 3, " ")
    gui.centerText(2, title, gui.colors.text)
    gui.gpu.setBackground(gui.colors.background)
end

-- Нарисовать кнопку
function gui.drawButton(x, y, width, height, text, color, textColor)
    color = color or gui.colors.button
    textColor = textColor or gui.colors.text
    
    gui.gpu.setBackground(color)
    gui.gpu.fill(x, y, width, height, " ")
    
    gui.gpu.setForeground(textColor)
    local textX = x + math.floor((width - unicode.len(text)) / 2)
    local textY = y + math.floor(height / 2)
    gui.gpu.set(textX, textY, text)
    
    gui.gpu.setBackground(gui.colors.background)
    
    return {x = x, y = y, width = width, height = height}
end

-- Проверить нажатие на кнопку
function gui.isButtonClicked(button, clickX, clickY)
    return clickX >= button.x and clickX < button.x + button.width and
           clickY >= button.y and clickY < button.y + button.height
end

-- Нарисовать список руд
function gui.drawOreList(ores, startY)
    local y = startY
    local oreList = {}
    
    gui.gpu.setForeground(gui.colors.text)
    gui.gpu.set(3, y, "═══ Найденные руды ═══")
    y = y + 2
    
    for oreName, oreData in pairs(ores) do
        local rate = oreData.rate
        local canExchange = math.floor(oreData.total / rate.input)
        
        local statusColor = canExchange > 0 and gui.colors.success or gui.colors.error
        gui.gpu.setForeground(gui.colors.text)
        gui.gpu.set(3, y, oreData.label or oreName)
        
        gui.gpu.setForeground(statusColor)
        local countText = string.format(" x%d (обменов: %d)", oreData.total, canExchange)
        gui.gpu.set(3 + unicode.len(oreData.label or oreName), y, countText)
        
        table.insert(oreList, {
            y = y,
            name = oreName,
            data = oreData,
            canExchange = canExchange
        })
        
        y = y + 1
    end
    
    gui.gpu.setForeground(gui.colors.text)
    return oreList, y
end

-- Нарисовать выбор выхода для руды с альтернативами
function gui.drawOutputSelection(ore, startY)
    local y = startY
    local buttons = {}
    
    gui.gpu.setForeground(gui.colors.highlight)
    gui.gpu.set(3, y, "Выберите что получить за " .. (ore.label or ore.name) .. ":")
    y = y + 2
    
    for i, output in ipairs(ore.rate.outputs) do
        local buttonWidth = math.min(gui.width - 6, 40)
        local buttonText = string.format("%d. %s x%d", i, output.label, output.amount)
        local btn = gui.drawButton(3, y, buttonWidth, 3, buttonText)
        btn.outputIndex = i
        btn.output = output
        table.insert(buttons, btn)
        y = y + 4
    end
    
    return buttons, y
end

-- Нарисовать прогресс-бар
function gui.drawProgressBar(x, y, width, progress, label)
    gui.gpu.setForeground(gui.colors.text)
    gui.gpu.set(x, y, label or "")
    
    local barY = y + 1
    local filled = math.floor(width * progress)
    
    gui.gpu.setBackground(0x555555)
    gui.gpu.fill(x, barY, width, 1, " ")
    
    gui.gpu.setBackground(gui.colors.success)
    gui.gpu.fill(x, barY, filled, 1, " ")
    
    gui.gpu.setBackground(gui.colors.background)
    
    local percent = string.format(" %d%%", math.floor(progress * 100))
    gui.gpu.setForeground(gui.colors.text)
    gui.gpu.set(x + width + 1, barY, percent)
end

-- Показать сообщение
function gui.showMessage(message, color, y)
    y = y or math.floor(gui.height / 2)
    gui.centerText(y, message, color or gui.colors.text)
end

-- Показать сообщение об успехе
function gui.showSuccess(message)
    gui.showMessage(message, gui.colors.success)
end

-- Показать сообщение об ошибке
function gui.showError(message)
    gui.showMessage(message, gui.colors.error)
end

-- Ожидание нажатия
function gui.waitForTouch(timeout)
    timeout = timeout or 10
    local _, _, x, y = event.pull(timeout, "touch")
    return x, y
end

-- Нарисовать главный экран ожидания
function gui.drawWaitingScreen()
    gui.clear()
    gui.drawHeader("⚒ ОБМЕННИК РУДЫ ⚒")
    
    gui.centerText(math.floor(gui.height / 2) - 1, "Поместите ME ячейку с рудой", gui.colors.text)
    gui.centerText(math.floor(gui.height / 2) + 1, "в слот обменника", gui.colors.highlight)
    
    gui.gpu.setForeground(0x555555)
    gui.centerText(gui.height - 2, "Система автоматически обнаружит ячейку")
end

-- Нарисовать экран с результатами обмена
function gui.drawExchangeResult(exchanges, totalInput, totalOutput)
    gui.clear()
    gui.drawHeader("✓ ОБМЕН ЗАВЕРШЁН")
    
    local y = 5
    
    gui.gpu.setForeground(gui.colors.success)
    gui.gpu.set(3, y, "Успешно обменяно:")
    y = y + 2
    
    for _, ex in ipairs(exchanges) do
        gui.gpu.setForeground(gui.colors.text)
        local line = string.format("• %s x%d → %s x%d", 
            ex.inputLabel, ex.inputAmount, 
            ex.outputLabel, ex.outputAmount)
        gui.gpu.set(5, y, line)
        y = y + 1
    end
    
    y = y + 2
    gui.gpu.setForeground(gui.colors.highlight)
    gui.gpu.set(3, y, string.format("Итого: %d руды → %d предметов", totalInput, totalOutput))
    
    y = y + 3
    gui.drawButton(math.floor(gui.width/2) - 10, y, 20, 3, "Забрать ячейку", gui.colors.success)
end

-- Нарисовать экран подтверждения обмена
function gui.drawConfirmScreen(ores, selectedOutputs)
    gui.clear()
    gui.drawHeader("⚙ ПОДТВЕРЖДЕНИЕ ОБМЕНА")
    
    local y = 5
    gui.gpu.setForeground(gui.colors.text)
    gui.gpu.set(3, y, "Будет выполнен обмен:")
    y = y + 2
    
    local totalIn = 0
    local totalOut = 0
    
    for oreName, ore in pairs(ores) do
        local output = selectedOutputs[oreName] or ore.rate.outputs[1]
        local exchanges = math.floor(ore.total / ore.rate.input)
        
        if exchanges > 0 then
            local inputAmount = exchanges * ore.rate.input
            local outputAmount = exchanges * output.amount
            totalIn = totalIn + inputAmount
            totalOut = totalOut + outputAmount
            
            gui.gpu.setForeground(gui.colors.text)
            local line = string.format("• %s x%d → %s x%d", 
                ore.label or oreName, inputAmount, 
                output.label, outputAmount)
            gui.gpu.set(5, y, line)
            y = y + 1
        end
    end
    
    y = y + 2
    gui.gpu.setForeground(gui.colors.highlight)
    gui.gpu.set(3, y, string.format("Итого: %d руды → %d предметов", totalIn, totalOut))
    
    y = y + 3
    local confirmBtn = gui.drawButton(3, y, 20, 3, "✓ Подтвердить", gui.colors.success)
    local cancelBtn = gui.drawButton(26, y, 20, 3, "✗ Отмена", gui.colors.error)
    
    return confirmBtn, cancelBtn
end

return gui
