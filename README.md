# noctalia-codeburn

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Noctalia plugin API 29](https://img.shields.io/badge/noctalia-plugin%20api%2029-7c5cff.svg)](https://github.com/noctalia-dev/noctalia-shell)
[![codeburn-rs](https://img.shields.io/badge/needs-codeburn--rs-111111.svg)](https://github.com/dvaxert/codeburn-rs)

Панель Noctalia для [codeburn-rs](https://github.com/dvaxert/codeburn-rs). На баре — огонёк и расход выбранного периода. В панели слева тот же расход, график токенов, модели, проекты и инструменты. Справа карточка лимитов: полоса заполнена тем, что ещё осталось, рядом процент и время сброса.

Нужны Noctalia 5.3 (plugin API 29) и бинарь `codeburn-rs` в `PATH` или в `~/.cargo/bin`.

## Поставить

Репозиторий подключается как path-источник. В `~/.local/state/noctalia/settings.toml`:

```toml
[plugins]
enabled = ["dvaxert/codeburn"]

[[plugins.source]]
kind = "path"
location = "/путь/к/noctalia-codeburn"
name = "codeburn"
```

На бар, в конец или в другое место, добавляется виджет:

```toml
"dvaxert/codeburn:bar"
```

Дальше `noctalia msg config-reload`. Клик по огоньку открывает панель. Правки `panel.luau` подхватываются сразу. Смена `plugin.toml` и файлов в `translations/` видна после выключения и включения плагина:

```bash
noctalia msg plugins disable dvaxert/codeburn
noctalia msg plugins enable dvaxert/codeburn
```

Проверка манифеста без сети: `noctalia plugins lint codeburn`.

## Что на экране

Кнопки периода шлют в сервис `today`, `week`, `30days`, `month` или `all`. Сервис запускает:

```bash
codeburn-rs status --format menubar-json --period <период>
```

и кладёт JSON в состояние `view`. Таймаут запуска — 60 секунд. Пока файлы читаются в первый раз, на баре стоит «—».

Полоса лимита показывает остаток: полная полоса значит, что окно почти не тронуто. Подпись «73% осталось» и строка сброса берутся из `limits` в том же JSON. Если сервис не ответил, карточка пишет, что лимиты не прочитались, а расход слева остаётся.

## Настройки

| Ключ | По умолчанию | Зачем |
|---|---|---|
| `binary` | пусто | путь к `codeburn-rs`. Пусто: сначала `PATH`, потом `~/.cargo/bin/codeburn-rs` |
| `period` | `today` | окно при старте сервиса. Панель может сменить его, пока настройки не трогали |
| `refresh_sec` | 60 | как часто сервис снова запускает бинарь, от 15 до 3600 |

## Лицензия

[MIT](LICENSE) © 2026 dvaxert
