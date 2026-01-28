-- Диагностический скрипт для ME Shop System
-- Запустите: lua debug.lua

print("=== ME SHOP DEBUG ===")
print("")

-- Шаг 1: Проверяем загрузку библиотеки component
print("[1] Загрузка библиотеки component...")
local success, component = pcall(require, "component")
if not success then
    print("ОШИБКА: Не удалось загрузить component: " .. tostring(component))
    return
end
print("OK: component загружен")
print("Тип: " .. type(component))
print("")

-- Шаг 2: Показываем все доступные методы component
print("[2] Методы библиотеки component:")
for k, v in pairs(component) do
    print("  " .. k .. " = " .. type(v))
end
print("")

-- Шаг 3: Получаем список ВСЕХ компонентов
print("[3] Список всех компонентов в системе:")
local count = 0
for address, ctype in component.list() do
    count = count + 1
    print("  " .. ctype .. " = " .. address:sub(1, 8) .. "...")
end
print("Всего компонентов: " .. count)
print("")

-- Шаг 4: Ищем ME компоненты
print("[4] Поиск ME компонентов...")
local meTypes = {"me_interface", "me_controller", "me_exportbus", "me_importbus"}
local foundME = false

for _, meType in ipairs(meTypes) do
    print("  Проверяю " .. meType .. "...")
    
    -- Способ 1: через list
    local addr = component.list(meType)()
    if addr then
        print("    НАЙДЕН через list(): " .. addr:sub(1, 8) .. "...")
        foundME = true
        
        -- Пробуем получить proxy
        print("    Пробую component.proxy()...")
        local ok, proxy = pcall(component.proxy, addr)
        if ok and proxy then
            print("    OK: proxy получен")
            print("    Методы компонента:")
            for k, v in pairs(proxy) do
                if type(v) == "function" then
                    print("      " .. k .. "()")
                end
            end
        else
            print("    ОШИБКА proxy: " .. tostring(proxy))
        end
    else
        print("    не найден")
    end
end

if not foundME then
    print("")
    print("!!! ME компоненты НЕ НАЙДЕНЫ !!!")
    print("")
    print("Убедитесь что:")
    print("1. Adapter подключен к ME Interface/Controller")
    print("2. ME сеть запитана энергией")
    print("3. Компьютер подключен к Adapter")
end
print("")

-- Шаг 5: Проверяем isAvailable
print("[5] Проверка component.isAvailable()...")
if component.isAvailable then
    for _, meType in ipairs(meTypes) do
        local available = component.isAvailable(meType)
        print("  " .. meType .. ": " .. tostring(available))
    end
else
    print("  ВНИМАНИЕ: isAvailable не существует!")
end
print("")

-- Шаг 6: Тестируем getItemsInNetwork если ME найден
print("[6] Тест getItemsInNetwork()...")
for _, meType in ipairs(meTypes) do
    local addr = component.list(meType)()
    if addr then
        local proxy = component.proxy(addr)
        if proxy and proxy.getItemsInNetwork then
            print("  Вызываю " .. meType .. ".getItemsInNetwork()...")
            local ok, items = pcall(proxy.getItemsInNetwork)
            if ok then
                print("  OK! Получено предметов: " .. #items)
                if #items > 0 then
                    print("  Первый предмет:")
                    for k, v in pairs(items[1]) do
                        print("    " .. tostring(k) .. " = " .. tostring(v))
                    end
                end
            else
                print("  ОШИБКА: " .. tostring(items))
            end
        else
            print("  getItemsInNetwork не найден в " .. meType)
        end
        break
    end
end

print("")
print("=== КОНЕЦ ДИАГНОСТИКИ ===")
