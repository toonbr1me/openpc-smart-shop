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

-- Берём первые 3 предмета для теста
local testCount = math.min(3, #items)
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
            
            -- Выводим все поля
            for k, v in pairs(dbItem) do
                if type(v) == "table" then
                    print("    " .. k .. ": <table>")
                    -- Пытаемся вывести содержимое таблицы
                    if k == "tag" or k == "nbt" then
                        print("      " .. serialization.serialize(v, 2))
                    end
                else
                    print("    " .. k .. ": " .. tostring(v))
                end
            end
            
            -- Специальная проверка NBT/display/Lore
            print("\n  Проверка NBT структуры:")
            if dbItem.tag then
                print("    ✓ tag существует")
                if dbItem.tag.display then
                    print("    ✓ tag.display существует")
                    if dbItem.tag.display.Lore then
                        print("    ✓ tag.display.Lore найден!")
                        print("\n    LORE СОДЕРЖИМОЕ:")
                        if type(dbItem.tag.display.Lore) == "table" then
                            for idx, line in ipairs(dbItem.tag.display.Lore) do
                                print("      [" .. idx .. "] " .. line)
                            end
                        else
                            print("      " .. tostring(dbItem.tag.display.Lore))
                        end
                    else
                        print("    ✗ tag.display.Lore отсутствует")
                    end
                    
                    if dbItem.tag.display.Name then
                        print("    ✓ tag.display.Name: " .. dbItem.tag.display.Name)
                    end
                else
                    print("    ✗ tag.display отсутствует")
                end
            elseif dbItem.nbt then
                print("    ✓ nbt существует (вместо tag)")
                if dbItem.nbt.display then
                    print("    ✓ nbt.display существует")
                    if dbItem.nbt.display.Lore then
                        print("    ✓ nbt.display.Lore найден!")
                        print("\n    LORE СОДЕРЖИМОЕ:")
                        if type(dbItem.nbt.display.Lore) == "table" then
                            for idx, line in ipairs(dbItem.nbt.display.Lore) do
                                print("      [" .. idx .. "] " .. line)
                            end
                        else
                            print("      " .. tostring(dbItem.nbt.display.Lore))
                        end
                    else
                        print("    ✗ nbt.display.Lore отсутствует")
                    end
                else
                    print("    ✗ nbt.display отсутствует")
                end
            else
                print("    ✗ Ни tag, ни nbt не найдены")
                print("    (Предмет не имеет NBT данных)")
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
print("\nВЫВОД:")
print("1. Если видите 'tag.display.Lore' - парсинг цен ВОЗМОЖЕН!")
print("2. Используйте me.store() для сохранения в Database")
print("3. Затем db.get() для получения полных NBT данных")
print("4. Парсите Lore только для выбранного предмета (экономия памяти)")
