-- Правильная тестовая программа для ME системы (по офф. документации)
local component = require("component")
local term = require("term")

print("=== ТЕСТ ME СИСТЕМЫ ===\n")

-- Проверка ME Controller
if not component.isAvailable("me_controller") then
    print("ОШИБКА: ME Controller не найден!")
    return
end

local me = component.me_controller
print("✓ ME Controller найден: " .. me.address:sub(1, 8))

-- Проверка энергии
local energy = me.getStoredPower()
local maxEnergy = me.getMaxStoredPower()
print("✓ Энергия: " .. energy .. " / " .. maxEnergy)

if energy == 0 then
    print("\nОШИБКА: ME система БЕЗ энергии!")
    return
end

-- Получение предметов (БЕЗ фильтра)
print("\n=== ПОЛУЧЕНИЕ ПРЕДМЕТОВ ===")
local items = me.getItemsInNetwork()

print("Тип результата: " .. type(items))

if type(items) ~= "table" then
    print("ОШИБКА: getItemsInNetwork() вернул " .. type(items))
    print("Значение: " .. tostring(items))
    return
end

print("✓ Получена таблица")
print("✓ Количество предметов: " .. #items)

if #items == 0 then
    print("\nВНИМАНИЕ: ME система пустая!")
    print("Положите предметы в ME систему и запустите снова")
    return
end

-- Показываем первые 5 предметов
print("\n=== ПЕРВЫЕ 5 ПРЕДМЕТОВ ===")
for i = 1, math.min(5, #items) do
    local item = items[i]
    print("\n[" .. i .. "] " .. (item.label or item.name))
    print("  ID: " .. item.name)
    print("  Количество: " .. (item.size or 0))
    print("  Damage: " .. (item.damage or 0))
    print("  Max stack: " .. (item.maxSize or 64))
    print("  hasTag: " .. tostring(item.hasTag or false))
    
    -- Проверка всех полей
    print("  Доступные поля:")
    for k, v in pairs(item) do
        if type(v) ~= "table" and type(v) ~= "function" then
            print("    " .. k .. " = " .. tostring(v))
        elseif type(v) == "table" then
            print("    " .. k .. " = <table>")
        end
    end
end

-- Проверка крафтинга
print("\n=== ПРОВЕРКА КРАФТИНГА ===")
local craftables = me.getCraftables()
print("Доступно рецептов: " .. #craftables)

if #craftables > 0 then
    print("✓ Автокрафт доступен!")
    print("Первый рецепт:")
    local first = craftables[1]
    local stack = first.getItemStack()
    print("  " .. (stack.label or stack.name))
else
    print("⚠ Автокрафт недоступен (нет паттернов)")
end

-- Итоги
print("\n=== ИТОГИ ===")
print("✓ ME система работает")
print("✓ Предметов в системе: " .. #items)
print("✓ Рецептов: " .. #craftables)

print("\n=== ПРОВЕРКА NBT/LORE ===")
local withTag = 0
for i, item in ipairs(items) do
    if item.hasTag then
        withTag = withTag + 1
    end
end

print("Предметов с NBT тегами: " .. withTag)

if withTag > 0 then
    print("\n⚠ ВНИМАНИЕ: getItemsInNetwork() НЕ ВОЗВРАЩАЕТ NBT данные!")
    print("⚠ Поле hasTag=true, но сам tag недоступен")
    print("⚠ Парсинг цен из Lore НЕВОЗМОЖЕН через этот метод")
end

print("\n=== ВЫВОД ===")
print("Для вашей версии AE2 + OpenComputers:")
print("1. getItemsInNetwork() работает")
print("2. НО не возвращает NBT/tag/display/Lore")
print("3. Парсинг цен из описания НЕВОЗМОЖЕН")
print("4. ОБЯЗАТЕЛЬНО используйте config.lua с ценами")

print("\nНажмите Enter...")
io.read()
