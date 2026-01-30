-- ═══════════════════════════════════════════════════════════════
-- УСТАНОВЩИК ОБМЕННИКА РУДЫ
-- Автоматически скачивает все файлы с GitHub
-- ═══════════════════════════════════════════════════════════════
-- 
-- Использование:
-- wget https://raw.githubusercontent.com/toonbr1me/openpc-smart-shop/main/install.lua
-- install
--
-- ═══════════════════════════════════════════════════════════════

local component = require("component")
local filesystem = require("filesystem")
local shell = require("shell")
local term = require("term")

-- ═══════════════════════════════════════════════════════════════
-- КОНФИГУРАЦИЯ
-- ═══════════════════════════════════════════════════════════════

local REPO_URL = "https://raw.githubusercontent.com/toonbr1me/openpc-smart-shop/main/"
local INSTALL_PATH = "/home/ore-exchange/"

local FILES = {
    -- Основные файлы
    { path = "main.lua", required = true },
    { path = "config.lua", required = true },
    { path = "config_extended.lua", required = false },
    
    -- Библиотеки
    { path = "lib/me_api.lua", required = true },
    { path = "lib/cell_api.lua", required = true },
    { path = "lib/gui.lua", required = true },
    
    -- Утилиты
    { path = "utils/scan_items.lua", required = false },
}

-- ═══════════════════════════════════════════════════════════════
-- ЦВЕТА И ВЫВОД
-- ═══════════════════════════════════════════════════════════════

local gpu = component.gpu

local colors = {
    header = 0x2D5A27,
    success = 0x27AE60,
    error = 0xE74C3C,
    warning = 0xF39C12,
    info = 0x3498DB,
    text = 0xFFFFFF,
    dim = 0x888888
}

local function setColor(color)
    if gpu then
        gpu.setForeground(color)
    end
end

local function resetColor()
    if gpu then
        gpu.setForeground(colors.text)
    end
end

local function printHeader()
    term.clear()
    setColor(colors.header)
    print("╔═══════════════════════════════════════════════════════════════╗")
    print("║                                                               ║")
    print("║           ⚒  УСТАНОВЩИК ОБМЕННИКА РУДЫ  ⚒                    ║")
    print("║              OpenComputers + AE2/ME                           ║")
    print("║                                                               ║")
    print("╚═══════════════════════════════════════════════════════════════╝")
    resetColor()
    print()
end

local function printStep(step, total, message)
    setColor(colors.info)
    io.write(string.format("[%d/%d] ", step, total))
    resetColor()
    print(message)
end

local function printSuccess(message)
    setColor(colors.success)
    print("  ✓ " .. message)
    resetColor()
end

local function printError(message)
    setColor(colors.error)
    print("  ✗ " .. message)
    resetColor()
end

local function printWarning(message)
    setColor(colors.warning)
    print("  ⚠ " .. message)
    resetColor()
end

local function printInfo(message)
    setColor(colors.dim)
    print("    " .. message)
    resetColor()
end

-- ═══════════════════════════════════════════════════════════════
-- ПРОВЕРКА ТРЕБОВАНИЙ
-- ═══════════════════════════════════════════════════════════════

local function checkRequirements()
    printStep(1, 5, "Проверка требований...")
    
    local issues = {}
    
    -- Проверяем интернет-карту
    if not component.isAvailable("internet") then
        table.insert(issues, "Интернет-карта не найдена!")
    else
        printSuccess("Интернет-карта обнаружена")
    end
    
    -- Проверяем GPU
    if not component.isAvailable("gpu") then
        printWarning("GPU не найден (GUI будет ограничен)")
    else
        printSuccess("GPU обнаружен")
    end
    
    -- Проверяем транспозер
    if not component.isAvailable("transposer") then
        printWarning("Транспозер не найден (нужен для работы)")
    else
        printSuccess("Транспозер обнаружен")
    end
    
    -- Проверяем ME
    if not component.isAvailable("me_controller") and not component.isAvailable("me_interface") then
        printWarning("ME система не найдена (нужна для работы)")
    else
        printSuccess("ME система обнаружена")
    end
    
    -- Проверяем место на диске
    local freeSpace = filesystem.spaceTotal("/") - filesystem.spaceUsed("/")
    if freeSpace < 50000 then
        table.insert(issues, "Недостаточно места на диске!")
    else
        printSuccess(string.format("Свободно %.1f KB на диске", freeSpace / 1024))
    end
    
    print()
    
    if #issues > 0 then
        setColor(colors.error)
        print("Обнаружены критические проблемы:")
        for _, issue in ipairs(issues) do
            print("  • " .. issue)
        end
        resetColor()
        return false
    end
    
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- СОЗДАНИЕ ДИРЕКТОРИЙ
-- ═══════════════════════════════════════════════════════════════

local function createDirectories()
    printStep(2, 5, "Создание директорий...")
    
    local dirs = {
        INSTALL_PATH,
        INSTALL_PATH .. "lib/",
        INSTALL_PATH .. "utils/"
    }
    
    for _, dir in ipairs(dirs) do
        if not filesystem.exists(dir) then
            filesystem.makeDirectory(dir)
            printSuccess("Создана: " .. dir)
        else
            printInfo("Существует: " .. dir)
        end
    end
    
    print()
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- СКАЧИВАНИЕ ФАЙЛОВ
-- ═══════════════════════════════════════════════════════════════

local function downloadFile(remotePath, localPath)
    local internet = require("internet")
    local url = REPO_URL .. remotePath
    
    local handle, err = internet.request(url)
    if not handle then
        return false, "Не удалось подключиться: " .. tostring(err)
    end
    
    local content = ""
    for chunk in handle do
        content = content .. chunk
    end
    
    if content == "" or content:find("404") then
        return false, "Файл не найден на сервере"
    end
    
    local file, err = io.open(localPath, "w")
    if not file then
        return false, "Не удалось создать файл: " .. tostring(err)
    end
    
    file:write(content)
    file:close()
    
    return true
end

local function downloadAllFiles()
    printStep(3, 5, "Скачивание файлов с GitHub...")
    print()
    
    local downloaded = 0
    local failed = 0
    
    for i, fileInfo in ipairs(FILES) do
        local localPath = INSTALL_PATH .. fileInfo.path
        io.write(string.format("    [%d/%d] %s ... ", i, #FILES, fileInfo.path))
        
        local success, err = downloadFile(fileInfo.path, localPath)
        
        if success then
            setColor(colors.success)
            print("OK")
            resetColor()
            downloaded = downloaded + 1
        else
            if fileInfo.required then
                setColor(colors.error)
                print("ОШИБКА")
                printError(err)
                resetColor()
                failed = failed + 1
            else
                setColor(colors.warning)
                print("ПРОПУЩЕНО")
                resetColor()
            end
        end
    end
    
    print()
    printInfo(string.format("Скачано: %d, Ошибок: %d", downloaded, failed))
    print()
    
    return failed == 0
end

-- ═══════════════════════════════════════════════════════════════
-- НАСТРОЙКА
-- ═══════════════════════════════════════════════════════════════

local function configure()
    printStep(4, 5, "Настройка...")
    
    -- Создаём скрипт запуска
    local runScript = [[#!/usr/bin/env lua
-- Запуск обменника руды
local shell = require("shell")
shell.setWorkingDirectory("]] .. INSTALL_PATH .. [[")
dofile("]] .. INSTALL_PATH .. [[main.lua")
]]
    
    local file = io.open("/usr/bin/ore-exchange", "w")
    if file then
        file:write(runScript)
        file:close()
        printSuccess("Создан скрипт запуска: ore-exchange")
    end
    
    -- Создаём alias
    local aliasScript = 'alias ore="' .. INSTALL_PATH .. 'main.lua"\n'
    local shrc = io.open("/home/.shrc", "a")
    if shrc then
        shrc:write(aliasScript)
        shrc:close()
        printSuccess("Добавлен alias: ore")
    end
    
    print()
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- ЗАВЕРШЕНИЕ
-- ═══════════════════════════════════════════════════════════════

local function finish()
    printStep(5, 5, "Завершение установки...")
    print()
    
    setColor(colors.success)
    print("╔═══════════════════════════════════════════════════════════════╗")
    print("║                  УСТАНОВКА ЗАВЕРШЕНА!                         ║")
    print("╚═══════════════════════════════════════════════════════════════╝")
    resetColor()
    
    print()
    print("Файлы установлены в: " .. INSTALL_PATH)
    print()
    
    setColor(colors.info)
    print("Следующие шаги:")
    resetColor()
    print("  1. Настройте компоненты (см. схему подключения)")
    print("  2. Отредактируйте config.lua под ваши руды")
    print("  3. Используйте utils/scan_items.lua для поиска ID предметов")
    print()
    
    setColor(colors.header)
    print("Команды запуска:")
    resetColor()
    print("  • ore-exchange     - запуск программы")
    print("  • ore              - короткий alias")
    print("  • " .. INSTALL_PATH .. "main.lua")
    print()
    
    setColor(colors.warning)
    print("Важно: Проверьте подключение транспозера и ME системы!")
    resetColor()
    print()
end

-- ═══════════════════════════════════════════════════════════════
-- ГЛАВНАЯ ФУНКЦИЯ
-- ═══════════════════════════════════════════════════════════════

local function main()
    printHeader()
    
    print("Этот скрипт установит Обменник Руды на ваш компьютер.")
    print("Репозиторий: github.com/toonbr1me/openpc-smart-shop")
    print()
    
    io.write("Продолжить установку? [Y/n]: ")
    local answer = io.read()
    if answer and answer:lower() == "n" then
        print("Установка отменена.")
        return
    end
    
    print()
    
    if not checkRequirements() then
        print()
        io.write("Продолжить несмотря на предупреждения? [y/N]: ")
        local answer = io.read()
        if not answer or answer:lower() ~= "y" then
            print("Установка отменена.")
            return
        end
    end
    
    if not createDirectories() then
        printError("Не удалось создать директории!")
        return
    end
    
    if not downloadAllFiles() then
        printError("Не все файлы были скачаны!")
        io.write("Продолжить? [y/N]: ")
        local answer = io.read()
        if not answer or answer:lower() ~= "y" then
            return
        end
    end
    
    configure()
    finish()
end

-- Запуск
main()
