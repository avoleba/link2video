require 'open-uri'
require 'net/http'
require 'json'
require 'httparty'
require 'nokogiri'
require 'telegram/bot'

class VideoDownloader
  class << self
    # Основной метод для получения видео
    def get_video(url)
      platform = detect_platform(url)
      
      case platform
      when :youtube
        download_youtube(url)
      when :instagram
        download_instagram(url)
      when :tiktok
        download_tiktok(url)
      else
        { error: "Неподдерживаемая платформа" }
      end
    rescue => e
      { error: "Ошибка: #{e.message}" }
    end
    
    # Определение платформы
    def detect_platform(url)
      if url.include?('youtube.com') || url.include?('youtu.be')
        :youtube
      elsif url.include?('instagram.com')
        :instagram
      elsif url.include?('tiktok.com')
        :tiktok
      else
        :unknown
      end
    end
    
    # YouTube Downloader
    def download_youtube(url)
      # Используем yt-dlp через API или локально
      result = fetch_from_youtube_api(url)
      
      result || { error: "Не удалось получить видео с YouTube" }
    end
    
    # Instagram Downloader
    def download_instagram(url)
      result = fetch_instagram_video(url)
      result || { error: "Не удалось получить видео с Instagram" }
    end
    
    # TikTok Downloader
    def download_tiktok(url)
      result = fetch_tiktok_video(url)
      result || { error: "Не удалось получить видео с TikTok" }
    end
    
    # Получение информации о видео без скачивания
    def get_video_info(url)
      case detect_platform(url)
      when :youtube
        get_youtube_info(url)
      when :instagram
        get_instagram_info(url)
      when :tiktok
        get_tiktok_info(url)
      else
        { error: "Неподдерживаемая платформа" }
      end
    end
    
    private
    
    # YouTube методы
    def fetch_from_youtube_api(url)
      # Используем бесплатный API oEmbed
      api_url = "https://www.youtube.com/oembed?url=#{URI.encode_uri_component(url)}&format=json"
      
      response = HTTParty.get(api_url, timeout: 10)
      
      if response.success?
        data = JSON.parse(response.body)
        
        {
          success: true,
          platform: :youtube,
          title: data['title'],
          author: data['author_name'],
          thumbnail_url: data['thumbnail_url'],
          video_url: url,
          embed_url: "https://www.youtube.com/embed/#{extract_youtube_id(url)}"
        }
      else
        nil
      end
    rescue => e
      puts "YouTube API error: #{e.message}"
      nil
    end
    
    def get_youtube_info(url)
      begin
        # Упрощенная версия без гема video_info
        api_url = "https://www.youtube.com/oembed?url=#{URI.encode_uri_component(url)}&format=json"
        response = HTTParty.get(api_url, timeout: 10)
        
        if response.success?
          data = JSON.parse(response.body)
          
          {
            platform: :youtube,
            title: data['title'],
            author: data['author_name'],
            thumbnail: data['thumbnail_url'],
            embed_url: "https://www.youtube.com/embed/#{extract_youtube_id(url)}"
          }
        else
          { error: "Не удалось получить информацию с YouTube" }
        end
      rescue => e
        { error: "YouTube ошибка: #{e.message}" }
      end
    end
    
    def extract_youtube_id(url)
      match = url.match(/(?:v=|\/)([a-zA-Z0-9_-]{11})/)
      match ? match[1] : nil
    end
    
    def get_instagram_info(url)
      InstagramVideoProcessor.get_video_for_telegram(url)
    end
    
    def fetch_tiktok_video(url)
      get_tiktok_info(url)
    end
    
    def get_tiktok_info(url)
      begin
        response = HTTParty.get(url, headers: tiktok_headers, follow_redirects: true)
        
        if response.success?
          html = response.body
          
          # Парсим мета-теги
          doc = Nokogiri::HTML(html)
          
          meta = {
            title: extract_meta_content(doc, 'og:title'),
            description: extract_meta_content(doc, 'og:description'),
            image: extract_meta_content(doc, 'og:image')
          }
          
          {
            platform: :tiktok,
            title: meta[:title] || 'TikTok Video',
            description: meta[:description],
            thumbnail: meta[:image],
            video_url: url
          }
        else
          { error: "Не удалось загрузить страницу TikTok" }
        end
      rescue => e
        { error: "TikTok ошибка: #{e.message}" }
      end
    end
    
    # Вспомогательные методы
    
    def instagram_headers
      {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
    end
    
    def tiktok_headers
      {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
    end
    
    def extract_meta_content(doc, property)
      meta = doc.at_css("meta[property='#{property}']")
      meta ? meta['content'] : nil
    end
  end
end