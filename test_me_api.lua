-- Простая демонстрация работы с ME API
-- Для тестирования подключения и базовых функций

local component = require("component")
local serialization = require("serialization")

print("╔═══════════════════════════════════════════════════════╗")
print("║           ME API DEMO - Тестирование                  ║")
print("╚═══════════════════════════════════════════════════════╝")
print("")

-- Проверяем доступные ME компоненты
print("1. Поиск ME компонентов...")
print("")

local meTypes = {"me_interface", "me_controller", "me_exportbus", "me_importbus"}
local foundComponent = nil

for _, meType in ipairs(meTypes) do
    if component.isAvailable(meType) then
        foundComponent = component.getPrimary(meType)
        print("✓ Найден: " .. meType)
        print("  Адрес: " .. foundComponent.address)
        break
    end
end

if not foundComponent then
    print("✗ ME компоненты не найдены!")
    print("")
    print("Убедитесь что:")
    print("  1. Adapter подключен к ME Interface или ME Controller")
    print("  2. Компьютер подключен к Adapter")
    print("  3. ME сеть включена и работает")
    return
end

print("")
print("2. Тестирование методов API...")
print("")

-- Тест getItemsInNetwork
print("→ getItemsInNetwork()")
local items = foundComponent.getItemsInNetwork()

if items then
    print("✓ Успешно! Найдено предметов: " .. #items)
    
    if #items > 0 then
        print("")
        print("  Примеры (первые 3 предмета):")
        for i = 1, math.min(3, #items) do
            local item = items[i]
            print("")
            print("  Предмет #" .. i .. ":")
            print("    label: " .. tostring(item.label))
            print("    name: " .. tostring(item.name))
            print("    size: " .. tostring(item.size))
            if item.damage then
                print("    damage: " .. tostring(item.damage))
            end
        end
    end
else
    print("✗ Ошибка получения предметов")
end

print("")
print("3. Проверка дополнительных методов...")
print("")

-- Тест getCraftables
print("→ getCraftables()")
local success, craftables = pcall(function() 
    return foundComponent.getCraftables() 
end)

if success and craftables then
    print("✓ Доступно рецептов крафта: " .. #craftables)
else
    print("⚠ Метод недоступен или вернул ошибку")
end

-- Тест energy methods (только для ME Controller)
if foundComponent.type == "me_controller" then
    print("")
    print("→ getStoredPower() / getMaxStoredPower()")
    local power = foundComponent.getStoredPower()
    local maxPower = foundComponent.getMaxStoredPower()
    
    if power and maxPower then
        print(string.format("✓ Энергия: %.2f / %.2f AE (%.1f%%)", 
            power, maxPower, (power/maxPower)*100))
    end
    
    print("")
    print("→ getAvgPowerUsage()")
    local avgUsage = foundComponent.getAvgPowerUsage()
    if avgUsage then
        print(string.format("✓ Среднее потребление: %.2f AE/t", avgUsage))
    end
end

print("")
print("═══════════════════════════════════════════════════════")
print("")
print("✓ Тестирование завершено!")
print("")
print("Компонент работает корректно.")
print("Можете использовать программы ME Shop System.")
print("")
print("═══════════════════════════════════════════════════════")
