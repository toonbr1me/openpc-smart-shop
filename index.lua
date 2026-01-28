--[[
  ME Shop System - Index file
  Версия: 1.0.0
  Дата: 29 января 2026
  
  Система для работы с Applied Energistics 2 через OpenComputers
]]

local system = {
  name = "ME Shop System",
  version = "1.0.0",
  author = "OpenPC Community",
  license = "MIT",
  
  files = {
    -- Основные программы
    main = "me_shop.lua",
    search = "price_search.lua",
    export = "export_prices.lua",
    monitor = "price_monitor.lua",
    
    -- Утилиты
    test = "test_me_api.lua",
    examples = "examples.lua",
    install = "install.lua",
    
    -- Конфигурация
    config = "config.lua",
    
    -- Документация
    readme = "README.md",
    quickstart = "QUICKSTART.md",
    overview = "OVERVIEW.md",
    commands = "COMMANDS.md"
  },
  
  requirements = {
    mods = {
      "OpenComputers 1.7+",
      "Applied Energistics 2 rv6+"
    },
    hardware = {
      "Computer Case (любой уровень)",
      "CPU T1+",
      "RAM 2x T1+",
      "HDD 1MB+",
      "Adapter",
      "ME Interface или ME Controller"
    }
  },
  
  features = {
    "Поиск предметов в ME сети",
    "Парсинг цен из описания",
    "Экспорт данных (TXT/JSON)",
    "Мониторинг изменений",
    "Статистика склада",
    "Интерактивное меню",
    "Гибкая настройка"
  }
}

-- Функция для отображения информации о системе
function system.info()
  print("╔═══════════════════════════════════════════════════════╗")
  print("║            " .. system.name .. "                    ║")
  print("║                  Версия " .. system.version .. "                     ║")
  print("╚═══════════════════════════════════════════════════════╝")
  print("")
  print("Основные программы:")
  print("  • me_shop.lua       - Главное меню")
  print("  • price_search.lua  - Быстрый поиск")
  print("  • export_prices.lua - Экспорт данных")
  print("  • price_monitor.lua - Мониторинг")
  print("")
  print("Утилиты:")
  print("  • test_me_api.lua   - Тест подключения")
  print("  • examples.lua      - Примеры кода")
  print("  • install.lua       - Установщик")
  print("")
  print("Документация:")
  print("  • README.md         - Полная документация")
  print("  • QUICKSTART.md     - Быстрый старт")
  print("  • OVERVIEW.md       - Обзор системы")
  print("  • COMMANDS.md       - Справка по командам")
  print("")
  print("Быстрый старт:")
  print("  1. lua test_me_api.lua    # Проверка")
  print("  2. lua me_shop.lua        # Запуск")
  print("")
  print("Лицензия: " .. system.license)
end

-- Если файл запущен напрямую, показываем информацию
if not ... then
  system.info()
end

return system
