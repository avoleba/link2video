# frozen_string_literal: true

require 'open-uri'
require 'net/http'
require 'json'
require 'httparty'
require 'nokogiri'
require 'telegram/bot'

# Фасад для получения информации о видео с разных платформ
class VideoDownloader
  class << self
    # @param platform [Symbol, String]
    # @param url [String]
    # @return [Hash{Symbol => Object}]
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

    # @param url [String]
    # @return [Hash{Symbol => Object}]
    def get_instagram_info(url)
      InstagramVideoProcessor.get_video_for_telegram(url)
    end

    # @param url [String]
    # @return [Hash{Symbol => Object}]
    def get_tiktok_info(url)
      TikTokVideoProcessor.get_video_for_telegram(url)
    end
  end
end
