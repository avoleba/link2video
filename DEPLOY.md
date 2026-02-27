# Деплой на сервер (Docker Compose)

Ниже — самый простой способ задеплоить этот бот на VPS (Ubuntu/Debian) через Docker.

## 1) Подготовка сервера

Установи Docker и Compose:

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
```

## 2) Подготовка проекта на сервере

Склонируй репозиторий:

```bash
git clone <your-repo-url> video-link-bot
cd video-link-bot
```

## 3) Секреты (env)

Создай файл `.env` рядом с `docker-compose.prod.yml`:

```bash
cat > .env <<'EOF'
TELEGRAM_BOT_TOKEN=__PUT_TOKEN_HERE__
DATABASE_PASSWORD=__PUT_DB_PASSWORD_HERE__
RAILS_MASTER_KEY=__PUT_MASTER_KEY_HERE__
EOF
```

Где взять `RAILS_MASTER_KEY`:
- локально: `cat config/master.key` (НЕ коммить в git)

## 4) Запуск

Собрать и поднять сервисы:

```bash
docker compose -f docker-compose.prod.yml --env-file .env up -d --build
```

Проверить логи:

```bash
docker compose -f docker-compose.prod.yml --env-file .env logs -f --tail=200 bot
docker compose -f docker-compose.prod.yml --env-file .env logs -f --tail=200 app
```

Остановить:

```bash
docker compose -f docker-compose.prod.yml --env-file .env down
```

## Что будет запущено

- `db` — Postgres
- `app` — Rails (порт 80) + Solid Queue внутри Puma (`SOLID_QUEUE_IN_PUMA=true`)
- `bot` — отдельный процесс, который запускает `rake bot:start` (long polling)

## Примечания

1) Для TikTok метаданных используется `yt-dlp` — он устанавливается внутри Docker-образа.
2) Если хочешь HTTPS и домен — проще всего поставить перед контейнером Caddy/Nginx или перейти на Kamal.

