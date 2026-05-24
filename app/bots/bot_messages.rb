# frozen_string_literal: true

# Тексты сообщений бота — вынесены в отдельный модуль для удобства правок
module BotMessages
  WELCOME = <<~TEXT.freeze
    🎬 *Video Downloader Bot*

    Я могу помочь вам скачать видео с популярных платформ!

    📋 *Поддерживаемые платформы:*
    • YouTube 🎥
    • Instagram 📸
    • TikTok 🎵

    ✨ *Просто отправьте мне ссылку на видео!*

    📌 *Примеры ссылок:*
    • https://youtube.com/watch?v=...
    • https://instagram.com/p/...
    • https://tiktok.com/@.../video/...

    📝 *Доступные команды:*
    /help - Справка
    /supported - Поддерживаемые платформы
    /stats - Статистика
  TEXT

  HELP = <<~TEXT.freeze
    ℹ️ *Как пользоваться ботом:*

    1. *Отправьте ссылку* на видео с YouTube, Instagram или TikTok
    2. Бот *проанализирует* ссылку
    3. Получите *информацию о видео* и опцию скачивания

    ⚠️ *Ограничения:*
    • Максимальный размер файла: 50MB
    • До 10 запросов в час
    • Некоторые видео могут быть недоступны

    🔒 *Конфиденциальность:*
    Ваши ссылки хранятся временно и удаляются через 24 часа.
  TEXT

  SUPPORTED = <<~TEXT.freeze
    📋 *Подробно о поддерживаемых платформах:*

    *YouTube* 🎥
    • Поддерживаются обычные видео
    • Короткие видео (Shorts)
    • Плейлисты (первое видео)

    *Instagram* 📸
    • Посты с видео (Reels, IGTV)
    • Истории (если публичные)
    • Не поддерживаются: приватные аккаунты

    *TikTok* 🎵
    • Все публичные видео
    • С музыкой и эффектами
    • Без водяных знаков (где возможно)

    🚀 *Просто отправьте ссылку!*
  TEXT

  UNKNOWN_COMMAND = "❌ Неизвестная команда. Используйте /help"
  ERROR_GENERIC = "⚠️ Произошла ошибка. Попробуйте позже."
  PROCESSING = "⏳ Обрабатываю ссылку...\n\n🔗 %{url}"

  # @param requests [ActiveRecord::Relation<VideoRequest>]
  # @return [String]
  def self.stats(requests)
    <<~TEXT
      📊 *Ваша статистика:*

      Всего запросов: #{requests.count}
      Успешно: #{requests.completed.count}
      В обработке: #{requests.processing.count}
      Не удалось: #{requests.failed.count}

      ⏰ *Последние запросы:*
      #{recent_requests_summary(requests)}
    TEXT
  end

  # @param requests [ActiveRecord::Relation<VideoRequest>]
  # @return [String]
  def self.recent_requests_summary(requests)
    recent = requests.order(created_at: :desc).limit(5)
    recent.map do |req|
      "• #{req.platform_name}: #{req.status_name} (#{time_ago(req.created_at)})"
    end.join("\n")
  end

  # @param time [Time, ActiveSupport::TimeWithZone]
  # @return [String]
  def self.time_ago(time)
    minutes = ((Time.current - time) / 60).to_i
    if minutes < 60
      "#{minutes} мин назад"
    else
      "#{(minutes / 60).to_i} ч назад"
    end
  end
end
