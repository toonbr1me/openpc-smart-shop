-- Установщик ME Shop System
-- Автоматическая установка всех программ

local shell = require("shell")
local filesystem = require("filesystem")
local component = require("component")

print("╔═══════════════════════════════════════════════════════╗")
print("║          ME SHOP SYSTEM - УСТАНОВЩИК                  ║")
print("╚═══════════════════════════════════════════════════════╝")
print("")

-- Проверка наличия интернета
local internet = component.isAvailable("internet")
if not internet then
    print("⚠ Внимание: Internet Card не обнаружена!")
    print("Скопируйте файлы вручную на компьютер.")
    return
end

print("✓ Internet Card найдена")

-- Проверка наличия ME компонента
local me = component.me_interface or component.me_controller or component.me_exportbus or component.me_importbus
if me then
    print("✓ ME компонент обнаружен: " .. me.type)
else
    print("⚠ ME компонент не найден. Убедитесь, что Adapter подключен к ME сети.")
end

print("")
print("Установка программ...")
print("")

-- Список файлов для загрузки
local files = {
    {name = "me_shop.lua", url = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/me_shop.lua"},
    {name = "price_search.lua", url = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/price_search.lua"},
    {name = "export_prices.lua", url = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/export_prices.lua"},
    {name = "price_monitor.lua", url = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/price_monitor.lua"}
}

-- Примечание: Так как у нас локальные файлы, создадим простую копию
print("Создание исполняемых файлов...")

-- Создаем директорию /usr/bin если её нет
if not filesystem.exists("/usr/bin") then
    filesystem.makeDirectory("/usr/bin")
end

-- Копируем файлы
local installedCount = 0
for _, file in ipairs(files) do
    local sourcePath = "/home/" .. file.name
    local destPath = "/usr/bin/" .. file.name:gsub("%.lua$", "")
    
    if filesystem.exists(sourcePath) then
        -- Копируем файл
        shell.execute("cp " .. sourcePath .. " " .. destPath)
        installedCount = installedCount + 1
        print("  ✓ " .. file.name .. " -> " .. destPath)
    else
        print("  ✗ " .. file.name .. " не найден")
    end
end

print("")
print("═══════════════════════════════════════════════════════")
print("")
print("Установка завершена!")
print("Установлено программ: " .. installedCount .. "/" .. #files)
print("")
print("Доступные команды:")
print("  me_shop        - Главная программа с меню")
print("  price_search   - Быстрый поиск предметов")
print("  export_prices  - Экспорт данных в файл")
print("  price_monitor  - Мониторинг изменений")
print("")
print("Попробуйте: me_shop")
print("═══════════════════════════════════════════════════════")
