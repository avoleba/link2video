class VideoProcessorJob < ActiveJob::Base
  queue_as :default
  
  def perform(request_id, processing_message_id = nil)
    request = VideoRequest.find(request_id)
    
    request.update!(status: :processing)
    
    video_info = VideoDownloader.get_video_info(request.url)
    
    if video_info[:error]
      request.update!(
        status: :failed,
        error_message: video_info[:error]
      )
      
      send_error_message(request, video_info[:error], processing_message_id)
    else
      request.update!(
        status: :completed,
        title: video_info[:title],
        author: video_info[:author],
        duration: video_info[:duration],
        thumbnail_url: video_info[:thumbnail],
        video_url: video_info[:video_url],
        platform: video_info[:platform].to_s
      )
      
      send_video_info(request, video_info, processing_message_id)
    end
  end
  
  private
  
  def send_error_message(request, error, processing_message_id)
    bot = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
    
    if processing_message_id
      bot.api.delete_message(
        chat_id: request.telegram_chat_id,
        message_id: processing_message_id
      )
    end
    
    text = <<~TEXT
      ❌ *Не удалось обработать ссылку*
      
      🔗 #{request.url}
      
      💡 *Причина:* #{error}
    TEXT
    
    bot.api.send_message(
      chat_id: request.telegram_chat_id,
      text: text,
      parse_mode: 'Markdown'
    )
  end
  
  def send_video_info(request, video_info, processing_message_id)
    bot = Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
    
    # if processing_message_id
    #   bot.api.delete_message(
    #     chat_id: request.telegram_chat_id,
    #     message_id: processing_message_id
    #   )
    # end
    
    text = <<~TEXT
      ✅ *Видео найдено!*
      
      📝 *Информация:*
      🏷️ *Название:* #{video_info[:title] || 'Не указано'}
      👤 *Автор:* #{video_info[:author] || 'Неизвестно'}
      ⏱️ *Длительность:* #{format_duration(video_info[:duration])}
      📊 *Платформа:* #{platform_emoji(video_info[:platform])} #{video_info[:platform].to_s.capitalize}
      
      🔗 *Исходная ссылка:* #{request.url}
    TEXT
    
    if video_info[:video_url]
      if video_info[:platform].to_s == 'instagram'
        send_instagram_video(bot, request, video_info)
      else
        text += "\n\n⬇️ *Ссылка для скачивания:* #{video_info[:video_url]}"
      end
    end
    
    if video_info[:platform].to_s == 'instagram'
      send_instagram_link(bot, request, video_info)
    else
      bot.api.send_message(
        chat_id: request.telegram_chat_id,
        text: 'text',
        parse_mode: 'Markdown',
        reply_markup: download_keyboard(request.id, video_info)
      )
    end
    
    # if video_info[:thumbnail]
    #   begin
    #     bot.api.send_photo(
    #       chat_id: request.telegram_chat_id,
    #       photo: video_info[:thumbnail],
    #       caption: "📸 Превью видео"
    #     )
    #   rescue
    #   end
    # end
  end

  def send_instagram_video(bot, request, video_info)
    begin
      # Пытаемся отправить видео файлом
      # Telegram поддерживает отправку видео по URL
      
      caption = "📸 *Instagram видео*\n\n"
      caption += "🎬 *#{video_info[:title]}*\n" if video_info[:title]
      caption += "👤 #{video_info[:author]}\n" if video_info[:author]
      caption += "\n✅ Видео загружено в Telegram"
      
      bot.api.send_video(
        chat_id: request.telegram_chat_id,
        video: video_info[:video_url],  # Прямая ссылка на видео
        caption: caption,
        parse_mode: 'Markdown',
        supports_streaming: true  # Позволяет потоковое воспроизведение
      )
      
    rescue Telegram::Bot::Exceptions::ResponseError => e
      # Если не получается отправить видео, отправляем как документ
      puts "Не удалось отправить видео: #{e.message}"
      puts video_info
      send_instagram_as_document(bot, request, video_info)
    end
  end

  def send_instagram_as_document(bot, request, video_info)
    caption = "📸 *Instagram видео*\n\n"
    caption += "🎬 *#{video_info[:title]}*\n" if video_info[:title]
    caption += "👤 #{video_info[:author]}\n" if video_info[:author]
    
    begin
      bot.api.send_document(
        chat_id: request.telegram_chat_id,
        document: video_info[:video_url],
        caption: caption,
        parse_mode: 'Markdown'
      )
    rescue => e
      # Если и документ не отправляется, отправляем ссылку
      puts "Не удалось отправить документ: #{e.message}"
      send_instagram_link(bot, request, video_info)
    end
  end

  def send_instagram_link(bot, request, video_info)
    text = "📸 *Instagram видео*\n\n"
    
    if video_info[:title]
      text += "🎬 *#{video_info[:title]}*\n"
    end
    
    if video_info[:author]
      text += "👤 *#{video_info[:author]}*\n\n"
    end
    
    text += "🔗 *Ссылка:* #{request.url}\n\n"
    text += "📱 *Как смотреть:*\n"
    text += "• Нажмите на ссылку выше\n"
    text += "• Instagram откроет видео в приложении\n"
    text += "• Или откройте в браузере"
    
    # Отправляем превью если есть
    if video_info[:thumbnail]
      begin
        bot.api.send_photo(
          chat_id: request.telegram_chat_id,
          photo: video_info[:thumbnail],
          caption: text,
          parse_mode: 'Markdown'
        )
        return
      rescue => e
        puts "Не удалось отправить фото: #{e.message}"
      end
    end

    bot.api.send_message(
      chat_id: request.telegram_chat_id,
      text: text,
      parse_mode: 'Markdown',
      disable_web_page_preview: false  # Разрешаем превью
    )
  end
  
  def download_keyboard(request_id, video_info)
    buttons = []
    
    if video_info[:video_url]
      buttons << [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: "⬇️ Скачать видео",
          url: video_info[:video_url]
        )
      ]
    end
    
    buttons << [
      Telegram::Bot::Types::InlineKeyboardButton.new(
        text: "ℹ️ Подробнее",
        callback_data: "more_info"
      )
    ]
    
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)
  end
  
  def format_duration(seconds)
    return "Неизвестно" unless seconds
    
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60
    
    if hours > 0
      format("%02d:%02d:%02d", hours, minutes, secs)
    else
      format("%02d:%02d", minutes, secs)
    end
  end
  
  def platform_emoji(platform)
    case platform.to_sym
    when :youtube then '🎥'
    when :instagram then '📸'
    when :tiktok then '🎵'
    else '🔗'
    end
  end
end