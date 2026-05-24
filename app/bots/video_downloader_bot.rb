# frozen_string_literal: true

require 'telegram/bot'

class VideoDownloaderBot
  include Aux::Pluggable

  TOKEN = ENV['TELEGRAM_BOT_TOKEN']

  # @!attribute [r] video_request_repository
  #   @return [VideoRequestRepository]
  resolve :video_request_repository, scope: nil

  # @return [void]
  def run
    puts "🤖 Запуск бота Video Downloader..."

    Telegram::Bot::Client.run(TOKEN) do |bot|
      bot.listen do |message|
        puts "message: #{message}"
        handle_message(bot, message)
      end
    end
  end

  private

  # @param bot [Telegram::Bot::Client]
  # @param message [Telegram::Bot::Types::Message, Telegram::Bot::Types::CallbackQuery]
  # @return [void]
  def handle_message(bot, message)
    case message
    when Telegram::Bot::Types::Message
      handle_text_message(bot, message)
    when Telegram::Bot::Types::CallbackQuery
      handle_callback(bot, message)
    end
  rescue StandardError => e
    puts "❌ Ошибка: #{e.message}"
    bot.api.send_message(
      chat_id: message.chat.id,
      text: BotMessages::ERROR_GENERIC
    )
  end

  # @param bot [Telegram::Bot::Client]
  # @param message [Telegram::Bot::Types::Message]
  # @return [void]
  def handle_text_message(bot, message)
    if message.text.start_with?('/')
      handle_command(bot, message)
    elsif valid_url?(message.text)
      handle_url(bot, message)
    else
      send_welcome_message(bot, message.chat.id)
    end
  end

  # @param bot [Telegram::Bot::Client]
  # @param message [Telegram::Bot::Types::Message]
  # @return [void]
  def handle_command(bot, message)
    case message.text
    when '/start'
      send_welcome_message(bot, message.chat.id)
    when '/help'
      send_help_message(bot, message.chat.id)
    when '/supported'
      send_supported_platforms(bot, message.chat.id)
    when '/stats'
      send_stats(bot, message.chat.id)
    else
      bot.api.send_message(
        chat_id: message.chat.id,
        text: BotMessages::UNKNOWN_COMMAND
      )
    end
  end

  # @param bot [Telegram::Bot::Client]
  # @param message [Telegram::Bot::Types::Message]
  # @return [void]
  def handle_url(bot, message)
    chat_id = message.chat.id
    url = message.text.strip
    puts "chat_id: #{chat_id}"
    puts "url: #{url}"

    request = video_request_repository.find_or_create_by(
      url: url,
      telegram_chat_id: chat_id,
      telegram_message_id: message.message_id,
      status: :processing
    )

    processing_msg = bot.api.send_message(
      chat_id: chat_id,
      text: format(BotMessages::PROCESSING, url: request.url),
      parse_mode: 'HTML'
    )

    puts "url: #{processing_msg}"

    VideoProcessorJob.perform_later(request.id, processing_msg['result']['message_id'])
  end

  # @param bot [Telegram::Bot::Client]
  # @param callback [Telegram::Bot::Types::CallbackQuery]
  # @return [void]
  def handle_callback(bot, callback)
    case callback.data
    when /^download_(.+)$/
      download_video(bot, callback, Regexp.last_match(1))
    when 'more_info'
      # show_more_info(bot, callback)
    end
  end

  # @param bot [Telegram::Bot::Client]
  # @param chat_id [Integer]
  # @return [void]
  def send_welcome_message(bot, chat_id)
    bot.api.send_message(
      chat_id: chat_id,
      text: BotMessages::WELCOME,
      parse_mode: 'Markdown'
    )
  end

  # @param bot [Telegram::Bot::Client]
  # @param chat_id [Integer]
  # @return [void]
  def send_help_message(bot, chat_id)
    bot.api.send_message(
      chat_id: chat_id,
      text: BotMessages::HELP,
      parse_mode: 'Markdown'
    )
  end

  # @param bot [Telegram::Bot::Client]
  # @param chat_id [Integer]
  # @return [void]
  def send_supported_platforms(bot, chat_id)
    bot.api.send_message(
      chat_id: chat_id,
      text: BotMessages::SUPPORTED,
      parse_mode: 'Markdown'
    )
  end

  # @param bot [Telegram::Bot::Client]
  # @param chat_id [Integer]
  # @return [void]
  def send_stats(bot, chat_id)
    requests = VideoRequest.where(telegram_chat_id: chat_id.to_s)
    bot.api.send_message(
      chat_id: chat_id,
      text: BotMessages.stats(requests),
      parse_mode: 'Markdown'
    )
  end

  # @param text [String]
  # @return [Boolean]
  def valid_url?(text)
    uri = URI.parse(text)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
end
