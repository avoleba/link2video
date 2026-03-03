require 'open-uri'
require 'net/http'
require 'json'
require 'httparty'
require 'nokogiri'
require 'telegram/bot'

class VideoDownloader
  class << self
    def get_video_info(platform, url)
      case platform.to_sym
      # when :youtube
      #   get_youtube_info(url)
      when :instagram
        get_instagram_info(url)
      when :tiktok
        get_tiktok_info(url)
      else
        { error: "Неподдерживаемая платформа" }
      end
    end
    
    private

    def get_instagram_info(url)
      InstagramVideoProcessor.get_video_for_telegram(url)
    end
    
    def get_tiktok_info(url)
      TikTokVideoProcessor.get_video_for_telegram(url)
    end   
  end
end
