-- Конфигурация обменника руды
-- Формат: [название_руды] = { input = количество_руды, outputs = { {item, amount, label}, ... } }

local config = {}

-- Курсы обмена руды на блоки/слитки
-- input - сколько руды нужно для обмена
-- outputs - варианты выхода (первый - по умолчанию, остальные - альтернативные)

config.exchangeRates = {
    -- Медная руда: 2 руды = 1 блок меди
    ["ic2:copper_ore"] = {
        input = 2,
        outputs = {
            { item = "ic2:copper_block", amount = 1, label = "Блок меди" }
        }
    },
    
    -- Железная руда: 2 руды = 1 блок железа
    ["minecraft:iron_ore"] = {
        input = 2,
        outputs = {
            { item = "minecraft:iron_block", amount = 1, label = "Блок железа" }
        }
    },
    
    -- Золотая руда: 2 руды = 1 блок золота
    ["minecraft:gold_ore"] = {
        input = 2,
        outputs = {
            { item = "minecraft:gold_block", amount = 1, label = "Блок золота" }
        }
    },
    
    -- Свинцовая руда: 1 руда = 1 слиток платины ИЛИ 1 блок свинца
    ["ic2:lead_ore"] = {
        input = 1,
        outputs = {
            { item = "ic2:lead_block", amount = 1, label = "Блок свинца" },
            { item = "thermalfoundation:ingot_platinum", amount = 1, label = "Слиток платины" }
        }
    },
    
    -- Никелевая руда: 1 руда = 1 слиток серебра ИЛИ 1 блок никеля
    ["thermalfoundation:ore_nickel"] = {
        input = 1,
        outputs = {
            { item = "thermalfoundation:storage_nickel", amount = 1, label = "Блок никеля" },
            { item = "thermalfoundation:ingot_silver", amount = 1, label = "Слиток серебра" }
        }
    },
    
    -- Оловянная руда: 2 руды = 1 блок олова
    ["ic2:tin_ore"] = {
        input = 2,
        outputs = {
            { item = "ic2:tin_block", amount = 1, label = "Блок олова" }
        }
    },
    
    -- Серебряная руда: 2 руды = 1 блок серебра
    ["thermalfoundation:ore_silver"] = {
        input = 2,
        outputs = {
            { item = "thermalfoundation:storage_silver", amount = 1, label = "Блок серебра" }
        }
    },
    
    -- Алмазная руда: 3 руды = 1 блок алмазов
    ["minecraft:diamond_ore"] = {
        input = 3,
        outputs = {
            { item = "minecraft:diamond_block", amount = 1, label = "Блок алмазов" }
        }
    },
    
    -- Изумрудная руда: 3 руды = 1 блок изумрудов
    ["minecraft:emerald_ore"] = {
        input = 3,
        outputs = {
            { item = "minecraft:emerald_block", amount = 1, label = "Блок изумрудов" }
        }
    },
    
    -- Редстоун руда: 2 руды = 1 блок редстоуна
    ["minecraft:redstone_ore"] = {
        input = 2,
        outputs = {
            { item = "minecraft:redstone_block", amount = 1, label = "Блок редстоуна" }
        }
    },
    
    -- Лазуритовая руда: 2 руды = 1 блок лазурита
    ["minecraft:lapis_ore"] = {
        input = 2,
        outputs = {
            { item = "minecraft:lapis_block", amount = 1, label = "Блок лазурита" }
        }
    }
}

-- Настройки ME системы
config.me = {
    -- Сторона адаптера ME (для ME Controller/Interface)
    side = "back",
    -- Таймаут операций (секунды)
    timeout = 5
}

-- Настройки транспозера для работы с ячейкой игрока
config.transposer = {
    -- Буферный сундук игрока (куда кладут переносную ячейку)
    bufferSide = 2,   -- front
    -- ME-привод (ME Drive) с пустым слотом для переносной ячейки
    driveSide = 3,    -- back
    -- Мусор/утилизация руды (сундук/ящик/лава под вакуум-хоппер) куда сбрасываем руду после списания
    trashSide = 5,    -- left
    -- Опционально: сундук с блоками/слитками для пополнения, если их нет в сети
    supplySide = nil,
    -- Слот переносной ячейки в буферном сундуке
    bufferSlot = 1,
    -- Слот в ME-приводе (обычно 1)
    driveSlot = 1
}

-- Настройки монитора
config.monitor = {
    -- Использовать GPU для отрисовки
    useGPU = true,
    -- Цвета интерфейса
    colors = {
        background = 0x1E1E1E,
        header = 0x2D5A27,
        text = 0xFFFFFF,
        highlight = 0x4A90D9,
        success = 0x27AE60,
        error = 0xE74C3C,
        button = 0x3498DB,
        buttonHover = 0x2980B9
    }
}

return config
