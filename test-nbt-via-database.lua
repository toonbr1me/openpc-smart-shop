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

-- Берём первые 10 предметов для теста
local testCount = math.min(20, #items)
print("Тестируем первые " .. testCount .. " предмета:\n")

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
            
            -- ПОЛНЫЙ дамп всех полей
            print("\n  === ПОЛНЫЙ СПИСОК ВСЕХ ПОЛЕЙ ===")
            local fieldCount = 0
            for k, v in pairs(dbItem) do
                fieldCount = fieldCount + 1
                local valueType = type(v)
                print("    [" .. fieldCount .. "] " .. k .. " (" .. valueType .. ")")
                
                if valueType == "table" then
                    print("        Таблица содержит " .. #v .. " элементов")
                    -- Рекурсивный вывод вложенных таблиц
                    for k2, v2 in pairs(v) do
                        local v2Type = type(v2)
                        print("          └─ " .. tostring(k2) .. " (" .. v2Type .. ")")
                        if v2Type == "table" then
                            for k3, v3 in pairs(v2) do
                                print("              └─ " .. tostring(k3) .. " (" .. type(v3) .. "): " .. tostring(v3))
                            end
                        else
                            print("              = " .. tostring(v2))
                        end
                    end
                elseif valueType == "string" or valueType == "number" or valueType == "boolean" then
                    print("        = " .. tostring(v))
                end
            end
            print("  Всего полей: " .. fieldCount)
            
            -- Пытаемся полную сериализацию
            print("\n  === ПОЛНАЯ СЕРИАЛИЗАЦИЯ ===")
            local serialized = serialization.serialize(dbItem, math.huge)
            -- Обрезаем если слишком длинное
            if #serialized > 1000 then
                print("    " .. serialized:sub(1, 1000) .. "\n    ... (обрезано, всего " .. #serialized .. " символов)")
            else
                print("    " .. serialized)
            end
            
            -- Специальная проверка NBT/display/Lore
            print("\n  === ПОИСК NBT СТРУКТУРЫ ===")
            
            -- Список возможных названий NBT поля
            local nbtFieldNames = {"tag", "nbt", "NBT", "Tag", "tags", "data", "stackTagCompound"}
            local foundNBT = false
            
            for _, fieldName in ipairs(nbtFieldNames) do
                if dbItem[fieldName] then
                    foundNBT = true
                    print("    ✓ Найдено поле: " .. fieldName)
                    print("    Тип: " .. type(dbItem[fieldName]))
                    
                    if type(dbItem[fieldName]) == "table" then
                        print("    Содержимое:")
                        print("    " .. serialization.serialize(dbItem[fieldName], 2))
                        
                        -- Ищем display
                        if dbItem[fieldName].display then
                            print("    ✓✓ display найден!")
                            
                            -- Ищем Lore
                            if dbItem[fieldName].display.Lore then
                                print("    ✓✓✓ LORE НАЙДЕН!")
                                print("\n    === СОДЕРЖИМОЕ LORE ===")
                                if type(dbItem[fieldName].display.Lore) == "table" then
                                    for idx, line in ipairs(dbItem[fieldName].display.Lore) do
                                        print("      [" .. idx .. "] " .. line)
                                    end
                                else
                                    print("      " .. tostring(dbItem[fieldName].display.Lore))
                                end
                            end
                        end
                    end
                end
            end
            
            if not foundNBT then
                print("    ✗ NBT поля не найдены")
                print("    Проверенные варианты: " .. table.concat(nbtFieldNames, ", "))
                print("    (Предмет возможно не имеет NBT или API не возвращает его)")
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
print("\nВЫВОДЫ:")
print("1. Если видите NBT поле с display.Lore - парсинг ВОЗМОЖЕН!")
print("2. Если все предметы без NBT - проверьте:")
print("   - Версию OpenComputers (нужна 1.7.5+)")
print("   - Версию AE2 (нужна rv6)")
print("   - Предметы должны иметь описание на сервере")
print("3. Используйте полную сериализацию чтобы увидеть структуру")
print("4. Если hasTag=true но NBT пустой - возможно ограничение API")
