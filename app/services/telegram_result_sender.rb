# frozen_string_literal: true

# Отправка результатов обработки видео в Telegram
class TelegramResultSender
  # @param request [VideoRequest]
  # @param error [String]
  # @param processing_message_id [Integer, nil]
  # @return [void]
  def self.send_error(request:, error:, processing_message_id: nil)
    new.send_error(request, error, processing_message_id)
  end

  # @param request [VideoRequest]
  # @param video_info [Hash{Symbol => Object}]
  # @param processing_message_id [Integer, nil]
  # @return [void]
  def self.send_success(request:, video_info:, processing_message_id: nil)
    new.send_success(request, video_info, processing_message_id)
  end

  # @param request [VideoRequest]
  # @param error [String]
  # @param processing_message_id [Integer, nil]
  # @return [void]
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

  # @param request [VideoRequest]
  # @param video_info [Hash{Symbol => Object}]
  # @param processing_message_id [Integer, nil]
  # @return [void]
  def send_success(request, video_info, processing_message_id)
    # if video_info[:platform] == :youtube
    #   return send_youtube_mini_app(request.telegram_chat_id, video_info[:video_id])
    # end

    if video_info[:video_url] && video_info[:platform] == :instagram
      send_instagram_video(request, video_info)
    elsif video_info[:video_url] && video_info[:platform] == :tiktok
      send_tik_tok_video(request, video_info, processing_message_id)
    end
  end

  private

  # @param str [String, nil]
  # @return [String]
  def escape_md(str)
    return '' if str.blank?

    str.to_s.gsub(/([\\*_`\[\]])/, "\\\\\\1")
  end

  # @return [Telegram::Bot::Client]
  def bot
    @bot ||= Telegram::Bot::Client.new(ENV['TELEGRAM_BOT_TOKEN'])
  end

  # @param request [VideoRequest]
  # @param video_info [Hash{Symbol => Object}]
  # @return [void]
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

  # @param request [VideoRequest]
  # @param video_info [Hash{Symbol => Object}]
  # @param _processing_message_id [Integer, nil]
  # @return [void]
  def send_tik_tok_video(request, video_info, _processing_message_id = nil)
    caption = "🎵 *TikTok видео*\n\n"
    caption += "🎬 *#{escape_md(video_info[:title])}*\n" if video_info[:title]
    caption += "👤 #{escape_md(video_info[:author])}\n" if video_info[:author]
    caption += "\n✅ Видео загружено в Telegram"

    bot.api.send_video(
      chat_id: request.telegram_chat_id,
      video: Faraday::UploadIO.new(video_info[:video_url], 'video/mp4'),
      caption: caption,
      parse_mode: 'Markdown',
      supports_streaming: true,
      reply_markup: download_keyboard(request.id, video_info)
    )
  rescue Telegram::Bot::Exceptions::ResponseError => e
    Rails.logger.warn("Telegram send_video (TikTok) failed: #{e.message}")
  end

  # @param request [VideoRequest]
  # @param video_info [Hash{Symbol => Object}]
  # @return [void]
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

  # @param chat_id [Integer, String]
  # @param video_id [String]
  # @return [void]
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

  # @param request_id [Integer]
  # @param video_info [Hash{Symbol => Object}]
  # @return [Telegram::Bot::Types::InlineKeyboardMarkup]
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
