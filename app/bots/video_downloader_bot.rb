require 'telegram/bot'

class VideoDownloaderBot
  TOKEN = ENV['TELEGRAM_BOT_TOKEN']
  
  def run
    puts "🤖 Запуск бота Video Downloader..."
    
    Telegram::Bot::Client.run(TOKEN) do |bot|
      bot.listen do |message|
        handle_message(bot, message)
      end
    end
  end
  
  private
  
  def handle_message(bot, message)
    case message
    when Telegram::Bot::Types::Message
      handle_text_message(bot, message)
    when Telegram::Bot::Types::CallbackQuery
      handle_callback(bot, message)
    end
  rescue => e
    puts "❌ Ошибка: #{e.message}"
    bot.api.send_message(
      chat_id: message.chat.id,
      text: "⚠️ Произошла ошибка. Попробуйте позже."
    )
  end
  
  def handle_text_message(bot, message)
    chat_id = message.chat.id
    
    if message.text.start_with?('/')
      p '1'
      handle_command(bot, message)
    elsif valid_url?(message.text)
      p '2'
      handle_url(bot, message)
    else
      p '3'
      send_welcome_message(bot, chat_id)
    end
  end
  
  def handle_command(bot, message)
    case message.text
    when '/start'
      send_welcome_message(bot, message.chat.id)
    when '/help'
      send_help_message(bot, message.chat.id)
    when '/supported'
      send_supported_platforms(bot, message.chat.id)
    when '/stats'
      send_stats(bot, message.chat.id, message.from.id)
    else
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "❌ Неизвестная команда. Используйте /help"
      )
    end
  end
  
  def handle_url(bot, message)
    chat_id = message.chat.id
    url = message.text.strip
    
    p 'Сохраняем запрос'
    request = VideoRequest.create!(
      url: url,
      telegram_chat_id: chat_id,
      telegram_message_id: message.message_id,
      status: :processing
    )
    
    p 'Отправляем сообщение о начале обработки'
    processing_msg = bot.api.send_message(
      chat_id: chat_id,
      text: "⏳ Обрабатываю ссылку...\n\n🔗 #{url}",
      parse_mode: 'HTML'
    )
    
    p 'Обрабатываем в фоне'
    p request.id
    p processing_msg['result']['message_id']
    VideoProcessorJob.perform_later(request.id, processing_msg['result']['message_id'])
  end
  
  def handle_callback(bot, callback)
    # Обработка callback кнопок
    case callback.data
    when /^download_(.+)$/
      request_id = $1
      download_video(bot, callback, request_id)
    when 'more_info'
      # show_more_info(bot, callback)
    end
  end
  
  def send_welcome_message(bot, chat_id)
    text = <<~TEXT
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
    
    bot.api.send_message(
      chat_id: chat_id,
      text: text,
      parse_mode: 'Markdown'
    )
  end
  
  def send_help_message(bot, chat_id)
    text = <<~TEXT
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
    
    bot.api.send_message(
      chat_id: chat_id,
      text: text,
      parse_mode: 'Markdown'
    )
  end
  
  def send_supported_platforms(bot, chat_id)
    text = <<~TEXT
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
    
    bot.api.send_message(
      chat_id: chat_id,
      text: text,
      parse_mode: 'Markdown'
    )
  end
  
  def send_stats(bot, chat_id, user_id)
    requests = VideoRequest.where(telegram_chat_id: chat_id.to_s)
    
    text = <<~TEXT
      📊 *Ваша статистика:*
      
      Всего запросов: #{requests.count}
      Успешно: #{requests.completed.count}
      В обработке: #{requests.processing.count}
      Не удалось: #{requests.failed.count}
      
      ⏰ *Последние запросы:*
      #{recent_requests_summary(requests)}
    TEXT
    
    bot.api.send_message(
      chat_id: chat_id,
      text: text,
      parse_mode: 'Markdown'
    )
  end
  
  def recent_requests_summary(requests)
    recent = requests.order(created_at: :desc).limit(5)
    
    recent.map do |req|
      "• #{req.platform_name}: #{req.status} (#{time_ago(req.created_at)})"
    end.join("\n")
  end
  
  def time_ago(time)
    minutes = ((Time.current - time) / 60).to_i
    if minutes < 60
      "#{minutes} мин назад"
    else
      "#{(minutes / 60).to_i} ч назад"
    end
  end
  
  def valid_url?(text)
    uri = URI.parse(text)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
end