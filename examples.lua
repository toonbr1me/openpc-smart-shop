-- Примеры использования ME Shop System API
-- Показывает различные способы работы с системой

local component = require("component")
local unicode = require("unicode")

-- Функция для безопасного поиска ME компонента
local function findMEComponent()
    local meTypes = {"me_interface", "me_controller", "me_exportbus", "me_importbus"}
    
    for _, meType in ipairs(meTypes) do
        local address = component.list(meType, true)()
        if address then
            return component.proxy(address)
        end
    end
    
    return nil
end

-- Получаем ME компонент
local me = findMEComponent()

if not me then
    print("ME компонент не найден!")
    return
end

print("=== ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ ME SHOP API ===")
print("")

-- ПРИМЕР 1: Получение всех предметов
print("1. Получение всех предметов в ME:")
print("   local items = me.getItemsInNetwork()")
local items = me.getItemsInNetwork()
print("   Результат: " .. #items .. " предметов найдено")
print("")

-- ПРИМЕР 2: Фильтрация по названию
print("2. Поиск предметов по названию (фильтр):")
print("   local diamonds = me.getItemsInNetwork({label=\"алмаз\"})")
local diamonds = me.getItemsInNetwork({label="алмаз"})
print("   Результат: " .. #diamonds .. " предметов")
if #diamonds > 0 then
    print("   Пример: " .. (diamonds[1].label or "N/A"))
end
print("")

-- ПРИМЕР 3: Структура данных предмета
if #items > 0 then
    print("3. Структура данных предмета:")
    local item = items[1]
    print("   {")
    print("     label = \"" .. tostring(item.label) .. "\"")
    print("     name = \"" .. tostring(item.name) .. "\"")
    print("     size = " .. tostring(item.size))
    if item.damage then
        print("     damage = " .. tostring(item.damage))
    end
    print("   }")
end
print("")

-- ПРИМЕР 4: Парсинг цены
print("4. Парсинг цены из названия:")
print("   function parsePrice(label)")
print("     return label:match(\"([%d%.]+)%$\")")
print("   end")
print("")

if #items > 0 then
    for _, item in ipairs(items) do
        if item.label then
            local price = item.label:match("([%d%.]+)%$")
            if price then
                print("   Пример: " .. item.label)
                print("   Цена: " .. price .. "$")
                break
            end
        end
    end
end
print("")

-- ПРИМЕР 5: Подсчет общей стоимости
print("5. Подсчет общей стоимости склада:")
print([[
   local totalValue = 0
   for _, item in ipairs(items) do
     local price = parsePrice(item.label)
     if price then
       totalValue = totalValue + (price * item.size)
     end
   end
]])

local totalValue = 0
for _, item in ipairs(items) do
    if item.label then
        local price = item.label:match("([%d%.]+)%$")
        if price then
            totalValue = totalValue + (tonumber(price) * item.size)
        end
    end
end
print("   Общая стоимость: " .. string.format("%.2f$", totalValue))
print("")

-- ПРИМЕР 6: Сортировка предметов
print("6. Сортировка предметов по количеству:")
print([[
   table.sort(items, function(a, b)
     return (a.size or 0) > (b.size or 0)
   end)
]])
local sortedItems = {}
for i, item in ipairs(items) do
    table.insert(sortedItems, item)
    if i >= 5 then break end
end
table.sort(sortedItems, function(a, b)
    return (a.size or 0) > (b.size or 0)
end)

print("   Топ 3 предмета по количеству:")
for i = 1, math.min(3, #sortedItems) do
    local item = sortedItems[i]
    print("   " .. i .. ". " .. (item.label or item.name) .. " - " .. item.size .. " шт.")
end
print("")

-- ПРИМЕР 7: Получение рецептов крафта (если доступно)
print("7. Получение доступных рецептов:")
print("   local craftables = me.getCraftables()")
local success, craftables = pcall(function()
    return me.getCraftables()
end)

if success and craftables then
    print("   Доступно рецептов: " .. #craftables)
    
    if #craftables > 0 then
        print("")
        print("   Пример работы с рецептом:")
        print([[
        local recipe = craftables[1]
        local itemStack = recipe.getItemStack()
        print(itemStack.label)
        
        -- Запросить крафт
        local status = recipe.request(1)  -- Скрафтить 1 штуку
        ]])
    end
else
    print("   Метод недоступен для этого компонента")
end
print("")

-- ПРИМЕР 8: Мониторинг изменений
print("8. Мониторинг изменений (псевдокод):")
print([[
   local oldItems = me.getItemsInNetwork()
   os.sleep(60)
   local newItems = me.getItemsInNetwork()
   
   -- Сравнение и вывод изменений
   for _, newItem in ipairs(newItems) do
     local found = false
     for _, oldItem in ipairs(oldItems) do
       if oldItem.name == newItem.name then
         found = true
         if oldItem.size ~= newItem.size then
           print("Изменение: " .. newItem.label)
           print("Было: " .. oldItem.size)
           print("Стало: " .. newItem.size)
         end
         break
       end
     end
     if not found then
       print("Новый предмет: " .. newItem.label)
     end
   end
]])
print("")

-- ПРИМЕР 9: Поиск предметов дороже определенной цены
print("9. Поиск дорогих предметов (цена > 5$):")
print([[
   local expensiveItems = {}
   for _, item in ipairs(items) do
     local price = parsePrice(item.label)
     if price and tonumber(price) > 5 then
       table.insert(expensiveItems, item)
     end
   end
]])

local expensiveCount = 0
for _, item in ipairs(items) do
    if item.label then
        local price = item.label:match("([%d%.]+)%$")
        if price and tonumber(price) > 5 then
            expensiveCount = expensiveCount + 1
        end
    end
end
print("   Найдено дорогих предметов: " .. expensiveCount)
print("")

-- ПРИМЕР 10: Экспорт в CSV
print("10. Экспорт в CSV формат:")
print([[
   local file = io.open("export.csv", "w")
   file:write("Название,ID,Количество,Цена\n")
   
   for _, item in ipairs(items) do
     local price = parsePrice(item.label) or "N/A"
     file:write(string.format("%s,%s,%d,%s\n",
       item.label, item.name, item.size, price))
   end
   
   file:close()
]])
print("")

print("=== ДОПОЛНИТЕЛЬНЫЕ ВОЗМОЖНОСТИ ===")
print("")
print("• Интеграция с Redstone для автоматизации")
print("• Создание веб-интерфейса через Internet Card")
print("• Автоматические уведомления о низких запасах")
print("• Интеграция с другими модами через Adapter")
print("• Создание системы автоматической торговли")
print("")
print("Полная документация: README.md")
print("Быстрый старт: QUICKSTART.md")
