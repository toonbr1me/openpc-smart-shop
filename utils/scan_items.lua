-- ═══════════════════════════════════════════════════════════════
-- УТИЛИТА ДЛЯ ОПРЕДЕЛЕНИЯ ИМЁН ПРЕДМЕТОВ
-- Помогает найти правильные ID для config.lua
-- ═══════════════════════════════════════════════════════════════

local component = require("component")
local sides = require("sides")

-- Инициализация транспозера
local transposer
if component.isAvailable("transposer") then
    transposer = component.transposer
else
    print("ОШИБКА: Транспозер не найден!")
    return
end

-- ═══════════════════════════════════════════════════════════════
-- ФУНКЦИИ
-- ═══════════════════════════════════════════════════════════════

local function getSideName(side)
    local names = {
        [0] = "bottom",
        [1] = "top",
        [2] = "front",
        [3] = "back",
        [4] = "right",
        [5] = "left"
    }
    return names[side] or "unknown"
end

local function scanInventory(side)
    local size = transposer.getInventorySize(side)
    if not size then
        print("Инвентарь не найден на стороне: " .. getSideName(side))
        return
    end
    
    print("\n═══ Сканирование инвентаря (" .. getSideName(side) .. ") ═══")
    print("Размер: " .. size .. " слотов\n")
    
    local items = {}
    
    for slot = 1, size do
        local stack = transposer.getStackInSlot(side, slot)
        if stack then
            local key = stack.name .. ":" .. (stack.damage or 0)
            if not items[key] then
                items[key] = {
                    name = stack.name,
                    label = stack.label,
                    damage = stack.damage or 0,
                    count = 0
                }
            end
            items[key].count = items[key].count + stack.size
        end
    end
    
    -- Выводим уникальные предметы
    print("Найденные предметы:\n")
    
    for _, item in pairs(items) do
        print("┌─────────────────────────────────────────────")
        print("│ Название: " .. item.label)
        print("│ ID: " .. item.name)
        print("│ Damage: " .. item.damage)
        print("│ Количество: " .. item.count)
        print("│")
        print("│ Для config.lua:")
        print("│ [\"" .. item.name .. "\"] = {")
        print("│     input = 2,")
        print("│     outputs = {")
        print("│         { item = \"minecraft:block\", amount = 1, label = \"" .. item.label .. "\" }")
        print("│     }")
        print("│ }")
        print("└─────────────────────────────────────────────\n")
    end
end

local function scanAllSides()
    print("\n╔═══════════════════════════════════════════════════════════╗")
    print("║         СКАНЕР ПРЕДМЕТОВ ДЛЯ ОБМЕННИКА РУДЫ               ║")
    print("╚═══════════════════════════════════════════════════════════╝")
    
    for side = 0, 5 do
        local size = transposer.getInventorySize(side)
        if size then
            scanInventory(side)
        end
    end
end

local function scanME()
    if not component.isAvailable("me_controller") and not component.isAvailable("me_interface") then
        print("ME система не подключена")
        return
    end
    
    local me = component.me_controller or component.me_interface
    local items = me.getItemsInNetwork()
    
    print("\n═══ Предметы в ME системе ═══\n")
    
    -- Группируем по типу (руды, блоки, слитки)
    local ores = {}
    local blocks = {}
    local ingots = {}
    local other = {}
    
    for _, item in pairs(items) do
        local name = item.name:lower()
        local label = (item.label or ""):lower()
        
        if name:find("ore") or label:find("руда") then
            table.insert(ores, item)
        elseif name:find("block") or name:find("storage") or label:find("блок") then
            table.insert(blocks, item)
        elseif name:find("ingot") or label:find("слиток") then
            table.insert(ingots, item)
        else
            table.insert(other, item)
        end
    end
    
    local function printCategory(name, items)
        if #items > 0 then
            print("\n── " .. name .. " ──")
            for _, item in ipairs(items) do
                print(string.format("  %s (x%d)", item.name, item.size))
                print(string.format("    Label: %s", item.label or "N/A"))
            end
        end
    end
    
    printCategory("РУДЫ", ores)
    printCategory("БЛОКИ", blocks)
    printCategory("СЛИТКИ", ingots)
    
    print("\n\nВсего типов предметов: " .. #items)
end

-- ═══════════════════════════════════════════════════════════════
-- МЕНЮ
-- ═══════════════════════════════════════════════════════════════

local function showMenu()
    print("\n╔═══════════════════════════════════════════════╗")
    print("║       УТИЛИТА СКАНИРОВАНИЯ ПРЕДМЕТОВ          ║")
    print("╠═══════════════════════════════════════════════╣")
    print("║ 1. Сканировать все инвентари (транспозер)     ║")
    print("║ 2. Сканировать ME систему                     ║")
    print("║ 3. Сканировать конкретную сторону             ║")
    print("║ 0. Выход                                      ║")
    print("╚═══════════════════════════════════════════════╝")
    print()
    io.write("Выберите опцию: ")
    
    local choice = io.read()
    
    if choice == "1" then
        scanAllSides()
    elseif choice == "2" then
        scanME()
    elseif choice == "3" then
        print("\nСтороны: 0=bottom, 1=top, 2=front, 3=back, 4=right, 5=left")
        io.write("Номер стороны: ")
        local side = tonumber(io.read())
        if side and side >= 0 and side <= 5 then
            scanInventory(side)
        else
            print("Неверный номер стороны!")
        end
    elseif choice == "0" then
        print("Выход.")
        return false
    else
        print("Неверный выбор!")
    end
    
    return true
end

-- Главный цикл
while showMenu() do end
