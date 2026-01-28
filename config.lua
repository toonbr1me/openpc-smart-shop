-- Файл конфигурации для ME Shop System
-- Настройка форматов цен и других параметров

local config = {}

-- Паттерны для парсинга цен (в порядке приоритета)
config.pricePatterns = {
    "Минимальная цена:%s*([%d%.]+)%$",  -- "Минимальная цена: 2.25$"
    "цена:%s*([%d%.]+)%$",               -- "цена: 2.25$"
    "Price:%s*([%d%.]+)%$",              -- "Price: 2.25$"
    "Цена:%s*([%d%.]+)%$",               -- "Цена: 2.25$"
    "([%d%.]+)%$",                       -- "2.25$"
    "([%d%.]+)руб",                      -- "2.25руб"
    "([%d%.]+)₽",                        -- "2.25₽"
}

-- Символ валюты для отображения
config.currencySymbol = "$"

-- Настройки отображения
config.display = {
    itemsPerPage = 20,           -- Количество предметов на странице
    maxNameLength = 48,          -- Максимальная длина имени предмета
    showItemID = false,          -- Показывать ID предмета (minecraft:diamond)
    showDamageValue = false,     -- Показывать damage/meta значение
}

-- Настройки фильтрации
config.filters = {
    minPrice = nil,              -- Минимальная цена для отображения (nil = без ограничений)
    maxPrice = nil,              -- Максимальная цена для отображения
    showOnlyWithPrice = false,   -- Показывать только предметы с ценами
    excludePatterns = {},        -- Паттерны для исключения предметов
    includePatterns = {},        -- Паттерны для включения (если пусто, то все)
}

-- Настройки экспорта
config.export = {
    defaultFormat = "txt",       -- Формат по умолчанию: txt, json, csv
    includeTimestamp = true,     -- Включать временную метку
    sortByPrice = true,          -- Сортировать по цене
}

-- Настройки мониторинга
config.monitor = {
    defaultInterval = 60,        -- Интервал проверки в секундах
    alertOnPriceChange = true,   -- Уведомлять об изменениях цен
    alertOnNewItems = true,      -- Уведомлять о новых предметах
    alertThreshold = 0.1,        -- Порог уведомления (10% изменения цены)
}

-- Настройки поиска
config.search = {
    caseSensitive = false,       -- Учитывать регистр при поиске
    exactMatch = false,          -- Точное совпадение
    searchInID = true,           -- Искать также в ID предмета
}

return config
