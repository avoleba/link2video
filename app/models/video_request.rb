# app/models/video_request.rb
class VideoRequest < ActiveRecord::Base
  # Не используем enum вообще
  STATUSES = { pending: 0, processing: 1, completed: 2, failed: 3 }.freeze
  PLATFORMS = { youtube: 0, instagram: 1, tiktok: 2, unknown: 3 }.freeze
  
  validates :url, presence: true
  
  before_validation :set_defaults
  
  def set_defaults
    self.status = STATUSES[:pending] if status.nil?
    self.platform = detect_platform if platform.nil?
  end
  
  def detect_platform
    if url.to_s.include?('youtube.com') || url.to_s.include?('youtu.be')
      PLATFORMS[:youtube]
    elsif url.to_s.include?('instagram.com')
      PLATFORMS[:instagram]
    elsif url.to_s.include?('tiktok.com')
      PLATFORMS[:tiktok]
    else
      PLATFORMS[:unknown]
    end
  end
  
  # Методы для проверки статуса
  def pending? = status == STATUSES[:pending]
  def processing? = status == STATUSES[:processing]
  def completed? = status == STATUSES[:completed]
  def failed? = status == STATUSES[:failed]
  
  # Методы для установки статуса
  def pending! = update(status: STATUSES[:pending])
  def processing! = update(status: STATUSES[:processing])
  def completed! = update(status: STATUSES[:completed])
  def failed! = update(status: STATUSES[:failed])
  
  # Методы для платформы
  def youtube? = platform == PLATFORMS[:youtube]
  def instagram? = platform == PLATFORMS[:instagram]
  def tiktok? = platform == PLATFORMS[:tiktok]
  def unknown? = platform == PLATFORMS[:unknown]
  
  # Хелпер для названия платформы
  def platform_name
    PLATFORMS.key(platform)&.to_s&.capitalize || 'Unknown'
  end
end