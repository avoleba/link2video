# frozen_string_literal: true

require_relative '../config/environment'

# @return [Thread]
Thread.new do
  begin
    TelegramBot.start
  rescue StandardError => e
    Rails.logger.error "Ошибка бота: #{e.message}"
    sleep 5
    retry
  end
end
