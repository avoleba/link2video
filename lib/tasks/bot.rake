# lib/tasks/bot.rake
namespace :bot do
  desc "Запуск Telegram бота"
  task start: :environment do
    puts "🤖 Запуск Video Downloader Bot..."
    VideoDownloaderBot.new.run
  end
  
  desc "Статистика бота"
  task stats: :environment do
    total = VideoRequest.count
    today = VideoRequest.where('created_at >= ?', Time.current.beginning_of_day).count
    
    puts "📊 Статистика бота:"
    puts "Всего запросов: #{total}"
    puts "Сегодня: #{today}"
    puts "По платформам:"
    VideoRequest.group(:platform).count.each do |platform, count|
      puts "  #{platform}: #{count}"
    end
    puts "По статусам:"
    VideoRequest.group(:status).count.each do |status, count|
      puts "  #{status}: #{count}"
    end
  end
  
  desc "Очистка старых запросов"
  task cleanup: :environment do
    old_requests = VideoRequest.where('created_at < ?', 7.days.ago)
    count = old_requests.count
    
    old_requests.destroy_all
    
    puts "🗑️ Удалено #{count} старых запросов"
  end
end