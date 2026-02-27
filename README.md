# Video Link Bot

Telegram-бот для получения видео и информации о роликах с **YouTube**, **Instagram** и **TikTok**. Пользователь отправляет ссылку — бот обрабатывает её в фоне и присылает данные о видео, превью и возможность скачать или посмотреть.

## Возможности

- **YouTube** — информация о видео, переход в мини-приложение для просмотра
- **Instagram** — загрузка видео в чат (Reels, посты с видео)
- **TikTok** — информация (название, автор, длительность) и отправка видео в Telegram

Поддерживаются команды: `/start`, `/help`, `/supported`, `/stats`.

## Стек

- **Ruby** 3.2+, **Rails** 8.1
- **PostgreSQL** — основная БД и очередь (Solid Queue)
- **Telegram Bot API** (long polling)
- **yt-dlp** — метаданные и ссылки для TikTok (и запасной вариант для других платформ)
- Обработка ссылок в фоне через **Solid Queue** (встроена в Puma в production)

## Требования

- Ruby 3.2+
- PostgreSQL
- Для TikTok (название, автор, длительность): **yt-dlp** (в Docker-образе уже есть)

## Быстрый старт (локально)

### 1. Клонирование и зависимости

```bash
git clone <repo-url> video-link-bot
cd video-link-bot
bundle install
```

### 2. База данных

Настрой `config/database.yml` под свою среду (логин/пароль PostgreSQL). Затем:

```bash
bin/rails db:create db:migrate
```

### 3. Переменные окружения

Создай `.env` в корне проекта (не коммить):

```bash
TELEGRAM_BOT_TOKEN=ваш_токен_от_@BotFather
```

Опционально для production: `RAILS_MASTER_KEY` (значение из `config/master.key`).

### 4. Запуск

Терминал 1 — веб и воркеры очереди:

```bash
bin/rails server
```

Терминал 2 — бот (long polling):

```bash
bin/rails bot:start
```

В development Solid Queue по умолчанию может использовать отдельную конфигурацию (см. `config/database.yml` и `config/queue.yml`). Если настроена отдельная БД для очереди — выполни миграции и для неё.

## Деплой (Docker)

Полная инструкция в [DEPLOY.md](DEPLOY.md). Кратко:

```bash
# .env: TELEGRAM_BOT_TOKEN, DATABASE_PASSWORD, RAILS_MASTER_KEY
docker compose -f docker-compose.prod.yml --env-file .env up -d --build
```

Запускаются: **db** (PostgreSQL), **app** (Rails + Solid Queue на порту 80), **bot** (процесс `rails bot:start`).

## Структура проекта

| Путь | Назначение |
|------|------------|
| `app/bots/` | Логика бота: `VideoDownloaderBot`, тексты сообщений |
| `app/jobs/video_processor_job.rb` | Фоновая обработка ссылки и отправка результата в Telegram |
| `app/services/video_downloader.rb` | Определение платформы, получение видео/метаданных (YouTube, Instagram, TikTok) |
| `app/services/telegram_result_sender.rb` | Формирование и отправка ответов пользователю |
| `app/models/video_request.rb` | Модель запроса (url, статус, результат) |
| `lib/tasks/bot.rake` | Задачи: `bot:start`, `bot:stats`, `bot:cleanup` |

## Полезные команды

```bash
bin/rails bot:start      # запуск бота
bin/rails bot:stats      # статистика запросов
bin/rails bot:cleanup    # удаление запросов старше 7 дней
```

## Лицензия

Частный проект. Использование по согласованию.
