-- Тест получения NBT данных через Database компонент
-- Требуется: Database Upgrade в Adapter рядом с ME Controller

local component = require("component")
local serialization = require("serialization")

print("=== Тест получения NBT через Database ===\n")

-- Проверка компонентов
if not component.isAvailable("me_controller") then
    print("ОШИБКА: ME Controller не найден!")
    return
end

if not component.isAvailable("database") then
    print("ОШИБКА: Database компонент не найден!")
    print("Необходимо: Database Upgrade в Adapter")
    return
end

local me = component.me_controller
local db = component.database

print("✓ ME Controller найден")
print("✓ Database найден (адрес: " .. db.address .. ")\n")

-- Получаем список предметов
print("Получаем список предметов из ME...")
local items = me.getItemsInNetwork()

if not items or type(items) ~= "table" or #items == 0 then
    print("ME система пуста или недоступна")
    return
end

print("Найдено предметов в ME: " .. #items .. "\n")

-- Тестируем больше предметов, особенно с hasTag=true
local testCount = math.min(10, #items)
print("Тестируем первые " .. testCount .. " предметов:")
print("(Ищем предметы с hasTag=true для анализа NBT)\n")

for i = 1, testCount do
    local item = items[i]
    print("─────────────────────────────────────")
    print("Предмет #" .. i .. ": " .. (item.label or item.name))
    print("  ID: " .. item.name)
    print("  Damage: " .. (item.damage or 0))
    print("  Количество: " .. item.size)
    print("  hasTag: " .. tostring(item.hasTag))
    
    -- Пытаемся сохранить предмет в Database
    print("\n  Попытка сохранить в Database слот " .. i .. "...")
    
    -- Очищаем слот перед записью
    db.clear(i)
    
    -- Используем store() для сохранения предмета
    -- store([filter:table,] [dbAddress:string,] [startSlot:number,] [count:number])
    local filter = {
        name = item.name,
        damage = item.damage
    }
    
    local success = me.store(filter, db.address, i, 1)
    
    if success then
        print("  ✓ Сохранено в Database!")
        
        -- Получаем полную информацию из Database
        local dbItem = db.get(i)
        
        if dbItem then
            print("\n  Данные из Database.get(" .. i .. "):")
            print("  ──────────────────────────")
            
            -- ПОЛНЫЙ ВЫВОД ВСЕХ ПОЛЕЙ С РЕКУРСИЕЙ
            local function printTable(tbl, indent, maxDepth)
                indent = indent or "    "
                maxDepth = maxDepth or 5
                if maxDepth <= 0 then
                    print(indent .. "<макс. глубина>")
                    return
                end
                
                for k, v in pairs(tbl) do
                    if type(v) == "table" then
                        print(indent .. k .. ": <table>")
                        -- Рекурсивно выводим содержимое
                        printTable(v, indent .. "  ", maxDepth - 1)
                    else
                        print(indent .. k .. ": " .. tostring(v))
                    end
                end
            end
            
            printTable(dbItem, "    ", 5)
            
            -- Для предметов с hasTag=true выводим сериализованные данные
            if item.hasTag then
                print("\n  СЕРИАЛИЗОВАННЫЕ ДАННЫЕ (для отладки):")
                print("  " .. ("─"):rep(38))
                local serialized = serialization.serialize(dbItem, math.huge)
                -- Выводим по частям чтобы не переполнить экран
                local maxLen = 500
                if #serialized > maxLen then
                    print(serialized:sub(1, maxLen))
                    print("  ... (обрезано, всего " .. #serialized .. " символов)")
                else
                    print(serialized)
                end
            end
            
            -- РЕКУРСИВНЫЙ ПОИСК LORE ВО ВСЕХ ВОЗМОЖНЫХ МЕСТАХ
            print("\n  Рекурсивный поиск 'Lore' и 'display':")
            local function findInTable(tbl, path, searchKey)
                path = path or "dbItem"
                local found = {}
                
                for k, v in pairs(tbl) do
                    local currentPath = path .. "." .. k
                    
                    -- Нашли искомый ключ
                    if k == searchKey then
                        table.insert(found, {path = currentPath, value = v})
                    end
                    
                    -- Рекурсивно ищем в подтаблицах
                    if type(v) == "table" then
                        local subFound = findInTable(v, currentPath, searchKey)
                        for _, item in ipairs(subFound) do
                            table.insert(found, item)
                        end
                    end
                end
                
                return found
            end
            
            -- Ищем "Lore"
            local loreFound = findInTable(dbItem, "dbItem", "Lore")
            if #loreFound > 0 then
                print("    ✓ НАЙДЕНО 'Lore' в " .. #loreFound .. " местах:")
                for _, item in ipairs(loreFound) do
                    print("      Путь: " .. item.path)
                    if type(item.value) == "table" then
                        for idx, line in ipairs(item.value) do
                            print("        [" .. idx .. "] " .. tostring(line))
                        end
                    else
                        print("        Значение: " .. tostring(item.value))
                    end
                end
            else
                print("    ✗ 'Lore' не найден нигде в структуре")
            end
            
            -- Ищем "display"
            local displayFound = findInTable(dbItem, "dbItem", "display")
            if #displayFound > 0 then
                print("\n    ✓ НАЙДЕНО 'display' в " .. #displayFound .. " местах:")
                for _, item in ipairs(displayFound) do
                    print("      Путь: " .. item.path)
                    if type(item.value) == "table" then
                        for k, v in pairs(item.value) do
                            print("        " .. k .. ": " .. tostring(v))
                        end
                    end
                end
            else
                print("    ✗ 'display' не найден нигде в структуре")
            end
            
            -- Ищем любые ключи содержащие "lore" (регистронезависимо)
            print("\n    Поиск ключей содержащих 'lore' (lowercase):")
            local function findKeysContaining(tbl, path, searchStr)
                path = path or "dbItem"
                local found = {}
                searchStr = searchStr:lower()
                
                for k, v in pairs(tbl) do
                    if type(k) == "string" and k:lower():find(searchStr) then
                        table.insert(found, {path = path .. "." .. k, key = k, value = v})
                    end
                    
                    if type(v) == "table" then
                        local subFound = findKeysContaining(v, path .. "." .. k, searchStr)
                        for _, item in ipairs(subFound) do
                            table.insert(found, item)
                        end
                    end
                end
                
                return found
            end
            
            local loreKeys = findKeysContaining(dbItem, "dbItem", "lore")
            if #loreKeys > 0 then
                print("    ✓ Найдено ключей с 'lore': " .. #loreKeys)
                for _, item in ipairs(loreKeys) do
                    print("      " .. item.path)
                end
            else
                print("    ✗ Ключей содержащих 'lore' не найдено")
            end
            
            -- Вычисляем хеш для сравнения
            local hash = db.computeHash(i)
            print("\n  Hash предмета: " .. hash)
            
        else
            print("  ✗ Database.get() вернул nil!")
        end
    else
        print("  ✗ Ошибка сохранения в Database")
        print("  (Возможно предмет не найден в ME или Database полон)")
    end
    
    print("")
end

print("\n=== Тест завершён ===")
print("\nЧТО ПРОВЕРЯЛОСЬ:")
print("1. ВСЕ поля из db.get() с рекурсивным выводом (глубина 5)")
print("2. Рекурсивный поиск 'Lore' во всей структуре")
print("3. Рекурсивный поиск 'display' во всей структуре")
print("4. Поиск любых ключей содержащих 'lore'")
print("5. Сериализованный вывод для hasTag=true предметов")
print("")
print("ВЫВОДЫ:")
print("• Если 'Lore' НЕ найден - предметы не имеют описания на сервере")
print("• Если 'display' НЕ найден - NBT структура отличается от стандартной")
print("• hasTag=true указывает что NBT есть, но может не содержать Lore")
print("")
print("СЛЕДУЮЩИЕ ШАГИ:")
print("1. Если Lore найден → используйте price-parser.lua")
print("2. Если Lore НЕ найден → используйте config.lua с ценами")
print("3. Попросите админа добавить Lore к предметам на сервере")
