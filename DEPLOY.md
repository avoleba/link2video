# Деплой на VPS (Docker Compose)

Краткая инструкция по деплою бота на VPS (Ubuntu/Debian).

## 1) Подготовка сервера

Подключись по SSH и установи Docker:

```bash
ssh user@IP_ТВОЕГО_VPS
```

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
```

Выйди из SSH и зайди снова (или выполни `newgrp docker`), чтобы группа `docker` применилась.

## 2) Клонирование проекта

```bash
git clone <url-твоего-репо> video-link-bot
cd video-link-bot
```

## 3) Секреты (.env)

Создай файл `.env` в корне проекта (рядом с `docker-compose.prod.yml`):

```bash
nano .env
```

Содержимое (подставь свои значения):

```
TELEGRAM_BOT_TOKEN=токен_от_BotFather
DATABASE_PASSWORD=надёжный_пароль_для_postgres
RAILS_MASTER_KEY=ключ_из_config_master_key
```

- **TELEGRAM_BOT_TOKEN** — выдаёт [@BotFather](https://t.me/BotFather).
- **DATABASE_PASSWORD** — придумай пароль для PostgreSQL.
- **RAILS_MASTER_KEY** — скопируй **локально** из файла `config/master.key` (в репозитории его нет, не коммить в git).

## 4) Запуск

Собрать образы и запустить контейнеры:

```bash
docker compose -f docker-compose.prod.yml --env-file .env up -d --build
```

При первом запуске образ собирается 2–5 минут. Миграции БД выполняются автоматически при старте (через `docker-entrypoint`).

## 5) Проверка

Статус контейнеров:

```bash
docker compose -f docker-compose.prod.yml --env-file .env ps
```

Логи бота и приложения:

```bash
docker compose -f docker-compose.prod.yml --env-file .env logs -f --tail=200 bot
docker compose -f docker-compose.prod.yml --env-file .env logs -f --tail=200 app
```

Отправь боту ссылку в Telegram — если в логах нет ошибок, деплой прошёл успешно.

## Остановка и обновление

Остановить:

```bash
docker compose -f docker-compose.prod.yml --env-file .env down
```

После `git pull` пересобрать и перезапустить:

```bash
docker compose -f docker-compose.prod.yml --env-file .env up -d --build
```

## Что запускается

| Сервис | Назначение |
|--------|------------|
| **db** | PostgreSQL 16 |
| **app** | Rails (порт 80), Puma + Solid Queue (фоновые задачи) |
| **bot** | Long polling Telegram (`rake bot:start`) |

## Дополнительно

- **yt-dlp** уже установлен в Docker-образ — метаданные TikTok подтягиваются без отдельной установки.
- Если нужен **HTTPS** и домен — поставь перед контейнером Caddy или Nginx, либо используй [Kamal](https://kamal-deploy.org/).
- Открыть порт 80 для входящих запросов (если нужен веб/прокси): `sudo ufw allow 80 && sudo ufw enable`

