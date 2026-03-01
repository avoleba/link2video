# Отправка результатов обработки видео в Telegram
class TelegramResultSender
  def self.send_error(request:, error:, processing_message_id: nil)
    new.send_error(request, error, processing_message_id)
  end

  def self.send_success(request:, video_info:, processing_message_id: nil)
    new.send_success(request, video_info, processing_message_id)
  end

  def send_error(request, error, processing_message_id)
    if processing_message_id
      bot.api.delete_message(
        chat_id: request.telegram_chat_id,
        message_id: processing_message_id
      )
    end

    text = <<~TEXT
      ❌ *Не удалось обработать ссылку*

      🔗 #{escape_md(request.url)}

      💡 *Причина:* #{escape_md(error)}
    TEXT

    bot.api.send_message(
      chat_id: request.telegram_chat_id,
      text: text,
      parse_mode: 'Markdown'
    )
  end

  def send_success(request, video_info, processing_message_id)
    # if video_info[:platform] == :youtube
    #   return send_youtube_mini_app(request.telegram_chat_id, video_info[:video_id])
    # end

    if video_info[:video_url] && video_info[:platform] == :instagram
      send_instagram_video(request, video_info)
    elsif video_info[:video_url] && video_info[:platform] == :tiktok && direct_media_url?(video_info[:video_url])
      send_tik_tok_video(request, video_info)
    end
  end

  private

  def escape_md(str)
    return '' if str.blank?
    str.to_s.gsub(/([\\*_`\[\]])/, "\\\\\\1")
  end

  def bot
    @bot ||= Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
  end

  def send_instagram_video(request, video_info)
    caption = "📸 *Instagram видео*\n\n"
    caption += "🎬 *#{escape_md(video_info[:title])}*\n" if video_info[:title]
    caption += "👤 #{escape_md(video_info[:author])}\n" if video_info[:author]
    caption += "\n✅ Видео загружено в Telegram"

    bot.api.send_video(
      chat_id: request.telegram_chat_id,
      video: video_info[:video_url],
      caption: caption,
      parse_mode: 'Markdown',
      supports_streaming: true,
      reply_markup: download_keyboard(request.id, video_info)
    )
  rescue Telegram::Bot::Exceptions::ResponseError => e
    Rails.logger.warn("Telegram send_video failed: #{e.message}")
    send_instagram_as_document(request, video_info)
  end

  def send_tik_tok_video(request, video_info)
    caption = "🎵 *TikTok видео*\n\n"
    caption += "🎬 *#{escape_md(video_info[:title])}*\n" if video_info[:title]
    caption += "👤 #{escape_md(video_info[:author])}\n" if video_info[:author]
    caption += "\n✅ Видео загружено в Telegram"

    # Сначала по URL; если Telegram не может скачать (403 и т.д.) — скачиваем сами и отправляем файлом
    bot.api.send_video(
      chat_id: request.telegram_chat_id,
      video: video_info[:video_url],
      caption: caption,
      parse_mode: 'Markdown',
      supports_streaming: true,
      reply_markup: download_keyboard(request.id, video_info)
    )
  rescue Telegram::Bot::Exceptions::ResponseError => e
    Rails.logger.warn("Telegram send_video (TikTok) failed: #{e.message}")
    send_tiktok_video_as_file(request, video_info)
  end

  def send_tiktok_video_as_file(request, video_info)
    caption = "🎵 *TikTok видео*\n\n"
    caption += "🎬 *#{escape_md(video_info[:title])}*\n" if video_info[:title]
    caption += "👤 #{escape_md(video_info[:author])}\n" if video_info[:author]
    caption += "\n✅ Видео загружено в Telegram"

    tempfile = download_tiktok_to_tempfile(video_info[:video_url], request.url)
    return send_tik_tok_as_document(request, video_info) unless tempfile

    bot.api.send_video(
      chat_id: request.telegram_chat_id,
      video: Faraday::UploadIO.new(tempfile.path, 'video/mp4'),
      caption: caption,
      parse_mode: 'Markdown',
      supports_streaming: true
    )
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def send_tik_tok_as_document(request, video_info)
    caption = "🎵 *TikTok видео*\n\n"
    caption += "🎬 *#{escape_md(video_info[:title])}*\n" if video_info[:title]
    caption += "👤 #{escape_md(video_info[:author])}\n" if video_info[:author]

    return unless direct_media_url?(video_info[:video_url])

    tempfile = download_tiktok_to_tempfile(video_info[:video_url], request.url)
    if tempfile
      bot.api.send_document(
        chat_id: request.telegram_chat_id,
        document: Faraday::UploadIO.new(tempfile.path, 'video/mp4', 'video.mp4'),
        caption: caption,
        parse_mode: 'Markdown'
      )
    else
      bot.api.send_document(
        chat_id: request.telegram_chat_id,
        document: video_info[:video_url],
        caption: caption,
        parse_mode: 'Markdown'
      )
    end
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def direct_media_url?(url)
    return false if url.blank?
    url.include?('tiktokcdn') || url.match?(/\.mp4(\?|$)/)
  end

  def download_tiktok_to_tempfile(video_url, referer)
    return nil unless direct_media_url?(video_url)
    headers = {
      'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer' => referer.to_s
    }
    response = HTTParty.get(video_url, headers: headers, timeout: 60)
    return nil unless response.success? && response.body.present?
    temp = Tempfile.new(['tiktok', '.mp4'])
    temp.binmode
    temp.write(response.body)
    temp.rewind
    temp
  rescue StandardError => e
    Rails.logger.warn("TikTok download to tempfile failed: #{e.message}")
    nil
  end

  def send_instagram_as_document(request, video_info)
    caption = "📸 *Instagram видео*\n\n"
    caption += "🎬 *#{escape_md(video_info[:title])}*\n" if video_info[:title]
    caption += "👤 #{escape_md(video_info[:author])}\n" if video_info[:author]

    bot.api.send_document(
      chat_id: request.telegram_chat_id,
      document: video_info[:video_url],
      caption: caption,
      parse_mode: 'Markdown'
    )
  rescue StandardError => e
    Rails.logger.warn("Telegram send_document failed: #{e.message}")
  end

  def send_youtube_mini_app(chat_id, video_id)
    web_app_url = "https://www.youtube.com/embed/#{video_id}?autoplay=1"

    keyboard = [
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(
          text: "🎬 Смотреть в Telegram",
          web_app: { url: web_app_url }
        )
      ]
    ]

    markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: keyboard)

    bot.api.send_message(
      chat_id: chat_id,
      text: "Нажмите кнопку для просмотра в Telegram",
      reply_markup: markup
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
end
