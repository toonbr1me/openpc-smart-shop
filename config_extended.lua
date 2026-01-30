-- ═══════════════════════════════════════════════════════════════
-- РАСШИРЕННЫЙ КОНФИГ ДЛЯ THERMAL/IC2/MEKANISM
-- ═══════════════════════════════════════════════════════════════
-- Скопируй нужные записи в config.lua

local extended = {}

extended.exchangeRates = {
    -- ═══════════════════════════════════════════════════════════
    -- ВАНИЛЬНЫЕ РУДЫ
    -- ═══════════════════════════════════════════════════════════
    
    ["minecraft:iron_ore"] = {
        input = 2,
        outputs = {
            { item = "minecraft:iron_block", amount = 1, label = "Блок железа" },
            { item = "minecraft:iron_ingot", amount = 9, label = "9 слитков железа" }
        }
    },
    
    ["minecraft:gold_ore"] = {
        input = 2,
        outputs = {
            { item = "minecraft:gold_block", amount = 1, label = "Блок золота" },
            { item = "minecraft:gold_ingot", amount = 9, label = "9 слитков золота" }
        }
    },
    
    ["minecraft:diamond_ore"] = {
        input = 3,
        outputs = {
            { item = "minecraft:diamond_block", amount = 1, label = "Блок алмазов" }
        }
    },
    
    ["minecraft:emerald_ore"] = {
        input = 3,
        outputs = {
            { item = "minecraft:emerald_block", amount = 1, label = "Блок изумрудов" }
        }
    },
    
    ["minecraft:redstone_ore"] = {
        input = 2,
        outputs = {
            { item = "minecraft:redstone_block", amount = 1, label = "Блок редстоуна" }
        }
    },
    
    ["minecraft:lapis_ore"] = {
        input = 2,
        outputs = {
            { item = "minecraft:lapis_block", amount = 1, label = "Блок лазурита" }
        }
    },
    
    ["minecraft:coal_ore"] = {
        input = 9,
        outputs = {
            { item = "minecraft:coal_block", amount = 1, label = "Блок угля" }
        }
    },
    
    -- ═══════════════════════════════════════════════════════════
    -- INDUSTRIAL CRAFT 2
    -- ═══════════════════════════════════════════════════════════
    
    ["ic2:resource:1"] = { -- Медная руда IC2
        input = 2,
        outputs = {
            { item = "ic2:resource:6", amount = 1, label = "Блок меди" }
        }
    },
    
    ["ic2:resource:2"] = { -- Оловянная руда IC2
        input = 2,
        outputs = {
            { item = "ic2:resource:7", amount = 1, label = "Блок олова" }
        }
    },
    
    ["ic2:resource:3"] = { -- Урановая руда IC2
        input = 1,
        outputs = {
            { item = "ic2:nuclear:5", amount = 2, label = "Уран-238" },
            { item = "ic2:nuclear:2", amount = 1, label = "Уран-235" }
        }
    },
    
    ["ic2:resource:4"] = { -- Свинцовая руда IC2
        input = 1,
        outputs = {
            { item = "ic2:resource:8", amount = 1, label = "Блок свинца" },
            { item = "thermalfoundation:material:134", amount = 1, label = "Слиток платины" }
        }
    },
    
    -- ═══════════════════════════════════════════════════════════
    -- THERMAL FOUNDATION
    -- ═══════════════════════════════════════════════════════════
    
    ["thermalfoundation:ore:0"] = { -- Медная руда Thermal
        input = 2,
        outputs = {
            { item = "thermalfoundation:storage:0", amount = 1, label = "Блок меди" }
        }
    },
    
    ["thermalfoundation:ore:1"] = { -- Оловянная руда Thermal
        input = 2,
        outputs = {
            { item = "thermalfoundation:storage:1", amount = 1, label = "Блок олова" }
        }
    },
    
    ["thermalfoundation:ore:2"] = { -- Серебряная руда
        input = 2,
        outputs = {
            { item = "thermalfoundation:storage:2", amount = 1, label = "Блок серебра" }
        }
    },
    
    ["thermalfoundation:ore:3"] = { -- Свинцовая руда Thermal
        input = 1,
        outputs = {
            { item = "thermalfoundation:storage:3", amount = 1, label = "Блок свинца" },
            { item = "thermalfoundation:material:134", amount = 1, label = "Слиток платины" }
        }
    },
    
    ["thermalfoundation:ore:4"] = { -- Алюминиевая руда
        input = 2,
        outputs = {
            { item = "thermalfoundation:storage:4", amount = 1, label = "Блок алюминия" }
        }
    },
    
    ["thermalfoundation:ore:5"] = { -- Никелевая руда
        input = 1,
        outputs = {
            { item = "thermalfoundation:storage:5", amount = 1, label = "Блок никеля" },
            { item = "thermalfoundation:material:130", amount = 1, label = "Слиток серебра" }
        }
    },
    
    ["thermalfoundation:ore:6"] = { -- Платиновая руда
        input = 1,
        outputs = {
            { item = "thermalfoundation:storage:6", amount = 1, label = "Блок платины" },
            { item = "thermalfoundation:material:135", amount = 1, label = "Слиток иридия" }
        }
    },
    
    ["thermalfoundation:ore:7"] = { -- Иридиевая руда
        input = 1,
        outputs = {
            { item = "thermalfoundation:storage:7", amount = 1, label = "Блок иридия" }
        }
    },
    
    ["thermalfoundation:ore:8"] = { -- Манаинфузная руда
        input = 2,
        outputs = {
            { item = "thermalfoundation:storage:8", amount = 1, label = "Блок манастали" }
        }
    },
    
    -- ═══════════════════════════════════════════════════════════
    -- MEKANISM
    -- ═══════════════════════════════════════════════════════════
    
    ["mekanism:oreblock:0"] = { -- Осмиевая руда
        input = 2,
        outputs = {
            { item = "mekanism:basicblock:0", amount = 1, label = "Блок осмия" }
        }
    },
    
    ["mekanism:oreblock:1"] = { -- Медная руда Mekanism
        input = 2,
        outputs = {
            { item = "mekanism:basicblock:1", amount = 1, label = "Блок меди" }
        }
    },
    
    ["mekanism:oreblock:2"] = { -- Оловянная руда Mekanism
        input = 2,
        outputs = {
            { item = "mekanism:basicblock:2", amount = 1, label = "Блок олова" }
        }
    },
    
    -- ═══════════════════════════════════════════════════════════
    -- IMMERSIVE ENGINEERING
    -- ═══════════════════════════════════════════════════════════
    
    ["immersiveengineering:ore:0"] = { -- Медная руда IE
        input = 2,
        outputs = {
            { item = "immersiveengineering:storage:0", amount = 1, label = "Блок меди" }
        }
    },
    
    ["immersiveengineering:ore:1"] = { -- Алюминиевая руда IE
        input = 2,
        outputs = {
            { item = "immersiveengineering:storage:1", amount = 1, label = "Блок алюминия" }
        }
    },
    
    ["immersiveengineering:ore:2"] = { -- Свинцовая руда IE
        input = 1,
        outputs = {
            { item = "immersiveengineering:storage:2", amount = 1, label = "Блок свинца" },
            { item = "thermalfoundation:material:134", amount = 1, label = "Слиток платины" }
        }
    },
    
    ["immersiveengineering:ore:3"] = { -- Серебряная руда IE
        input = 2,
        outputs = {
            { item = "immersiveengineering:storage:3", amount = 1, label = "Блок серебра" }
        }
    },
    
    ["immersiveengineering:ore:4"] = { -- Никелевая руда IE
        input = 1,
        outputs = {
            { item = "immersiveengineering:storage:4", amount = 1, label = "Блок никеля" },
            { item = "thermalfoundation:material:130", amount = 1, label = "Слиток серебра" }
        }
    },
    
    ["immersiveengineering:ore:5"] = { -- Урановая руда IE
        input = 1,
        outputs = {
            { item = "immersiveengineering:storage:5", amount = 1, label = "Блок урана" }
        }
    },
}

return extended
