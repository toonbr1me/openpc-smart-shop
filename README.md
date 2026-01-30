# Обменник руды для переносных ME ячеек

OpenComputers + Applied Energistics 2: автоматом меняет руды в переносной ячейке игрока на блоки/слитки из основной ME-сети и возвращает заполненную ячейку.

## Подключение
- Буферный сундук: публичный сундук, куда игрок кладёт переносную ячейку. Транспозер смотрит на него со стороны `bufferSide`.
- Processing ME Chest/Drive: изолированная подсеть, где временно стоит ячейка игрока. Транспозер подключён со стороны `processChestSide`, OC-адаптер видит `processing me_interface`.
- Fill chest: общий сундук, доступный обеим сетям. Главный ME интерфейс смотрит на него со стороны `mainOutputSide` и складывает выплаты; на сундуке должен стоять Import Bus в подсеть обработки, чтобы предметы ушли в ячейку.
- Trash: инвентарь/void на стороне `processingTrashSide`, куда списываются руды.
- Drop chest: куда возвращается готовая ячейка (`dropSide`).

## Конфиги
- [config/ae.lua](config/ae.lua) — адреса компонентов и стороны. После инсталлера замените заглушки.
- [config/app.lua](config/app.lua) — тайминги, лимиты, политика `requireFullPayout`.
- [config/rules.lua](config/rules.lua) — правила обмена руда→блок/слиток/бонус. Заполните реальные item id под ваш модпак.

## Как работает обмен
1) Транспозер перемещает ячейку из буфера в processing ME Chest/Drive.
2) `processingInterface.getItemsInNetwork()` читает содержимое; берутся только руды, подходящие под `rules.lua`.
3) Расчёт: `blocks = floor(n/blockCost)`, остаток → слитки, либо бонус `bonus.whenRemainder`.
4) Руды выбрасываются через `processingInterface.exportItem` на сторону мусора.
5) Выплаты запрашиваются из главной ME через `mainInterface.exportItem` в fill chest; Import Bus тянет их в подсеть и в ячейку.
6) Ячейка возвращается в drop chest.

## Шаги настройки
1) Расставьте блоки: буферный сундук, processing ME Chest/Drive, fill chest с Import Bus в подсеть, trash-выход, drop chest, один транспозер касающийся всех, два ME интерфейса (processing+main) под OC-адаптер.
2) На OC выполните `components`, впишите адреса и стороны в [config/ae.lua](config/ae.lua) (проще через инсталлер ниже).
3) Пропишите реальные предметы в [config/rules.lua](config/rules.lua).
4) Запустите `lua /scripts/exchanger.lua` и смотрите `/var/log/exchanger.log`.

### Быстрая установка одним файлом
- На OC выполните: `wget https://raw.githubusercontent.com/toonbr1me/openpc-smart-shop/main/installer.lua installer.lua`
- Затем: `lua installer.lua` — скачает все нужные файлы в `/config` и `/scripts` и положит README.
- После загрузки запустите интерактивный конфиг: `lua /scripts/install.lua`.

### Инсталлер
- На OC: `lua /scripts/install.lua`. Выберите transposer и два `me_interface`, укажите стороны — перезапишется [config/ae.lua](config/ae.lua).
- При необходимости после инсталла отредактируйте [config/rules.lua](config/rules.lua) и [config/app.lua](config/app.lua).

### Автозапуск rc.d
- Скопируйте [scripts/rc_exchanger.lua](scripts/rc_exchanger.lua) в `/etc/rc.d/exchanger.lua`.
- Включите и стартуйте: `rc exchanger enable`, затем `rc exchanger start`; статус: `rc exchanger status`.
- Логи: `/var/log/exchanger.log`. Перезапуск: `rc exchanger restart`.

## Примечания
- При `requireFullPayout = true` руда не тратится, если в главной сети не хватает выплат.
- `maxItemsPerCycle` ограничивает объём за цикл, чтобы большие ячейки не вешали сеть.
- Можно повесить экран/клавиатуру и tail лог для отображения хода обмена.
