rails serverrequire_relative '../config/environment'

Thread.new do
  begin
    TelegramBot.start
  rescue => e
    Rails.logger.error "Ошибка бота: #{e.message}"
    sleep 5
    retry
  end
end