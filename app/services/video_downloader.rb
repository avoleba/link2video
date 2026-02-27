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
        response = HTTParty.get(api_url, timeout: 60)

        if response.success?
          data = JSON.parse(response.body)
          
          {
            platform: :youtube,
            title: data['title'],
            author: data['author_name'],
            thumbnail: data['thumbnail_url'],
            video_url: url,
            embed_url: "https://www.youtube.com/embed/#{extract_youtube_id(url)}",
            video_id: extract_youtube_id(url),
            duration: nil
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
          doc = Nokogiri::HTML(html)
          
          meta = {
            title: extract_meta_content(doc, 'og:title'),
            description: extract_meta_content(doc, 'og:description'),
            image: extract_meta_content(doc, 'og:image')
          }
          
          # Прямая ссылка на видео (для загрузки в Telegram)
          direct_video_url = extract_tiktok_video_url(html, doc)
          yt_data = fetch_tiktok_ytdlp_json(url)
          direct_video_url = direct_video_url.presence || tiktok_url_from_ytdlp_json(yt_data)
          
          title = meta[:title].presence
          author = extract_tiktok_author(meta[:title])
          yt_meta = yt_data ? build_tiktok_metadata_from_ytdlp(yt_data) : nil
          if yt_meta
            title = yt_meta[:title] if title.blank? || title == 'TikTok Video'
            author = yt_meta[:author] if author.blank?
          end
          
          {
            platform: :tiktok,
            title: title.presence || 'TikTok Video',
            author: author,
            description: meta[:description],
            thumbnail: meta[:image],
            video_url: direct_video_url.presence || url,
            duration: yt_meta&.dig(:duration)
          }
        else
          { error: "Не удалось загрузить страницу TikTok" }
        end
      rescue => e
        { error: "TikTok ошибка: #{e.message}" }
      end
    end
    
    # Извлечение прямой ссылки на MP4 из HTML TikTok (JSON в странице)
    def extract_tiktok_video_url(html, doc)
      # 1) og:video:url — иногда есть
      og_video = doc.at_css("meta[property='og:video:url']")
      return og_video['content'] if og_video && og_video['content']&.match?(%r{\Ahttps?://})
      
      # 2) JSON в странице: url_list (часто в play_addr)
      if html.include?('url_list')
        # "url_list":["https:\/\/v16.tiktokcdn.com\/..."]
        html.scan(/"url_list"\s*:\s*\[\s*"((?:https?:\\?\/\\?\/[^"]+))"/) do |m|
          decoded = decode_tiktok_json_url(m[0])
          return decoded if decoded&.include?('tiktokcdn')
        end
      end
      # 3) play_addr / playAddr с полем url
      html.scan(/"url"\s*:\s*"((?:https?:\\?\/\\?\/[^"]*tiktokcdn[^"]*))"/) do |m|
        decoded = decode_tiktok_json_url(m[0])
        return decoded if decoded
      end
      # 4) Любая ссылка на tiktokcdn с .mp4
      match = html.match(/"((https?:\\?\/\\?\/[^"]*tiktokcdn[^"]*\.mp4[^"]*))"/)
      return decode_tiktok_json_url(match[1]) if match
      
      nil
    end
    
    def decode_tiktok_json_url(escaped)
      return nil unless escaped
      decoded = escaped.gsub('\\/', '/').gsub('\\u0026', '&').gsub('\\u003d', '=').gsub('\\u003D', '=')
      decoded = decoded.gsub(/\\u([0-9a-fA-F]{4})/) { |_| [$1.hex].pack('U').force_encoding('UTF-8') }
      decoded.match?(%r{\Ahttps?://}) ? decoded : nil
    end
    
    def extract_tiktok_author(og_title)
      return nil if og_title.blank?
      # "Author Name (@user) | TikTok" -> "Author Name (@user)" или оставляем как есть
      og_title.sub(/\s*\|\s*TikTok\s*$/i, '').strip.presence
    end
    
    def tiktok_url_from_ytdlp_json(data)
      return nil unless data
      data['url'].presence || data.dig('requested_downloads', 0, 'url')
    end

    def build_tiktok_metadata_from_ytdlp(data)
      return nil unless data
      dur = data['duration']
      duration_sec = dur && (d = dur.to_f) && d.positive? ? d.to_i : nil
      {
        title: (data['title'].presence || data['fulltitle'].presence),
        author: (data['uploader'].presence || data['creator'].presence || data['uploader_id'].presence&.then { "@#{_1}" }),
        duration: duration_sec
      }
    end

    # Запасной вариант: получить URL через yt-dlp (если установлен)
    def fetch_tiktok_url_via_ytdlp(url)
      tiktok_url_from_ytdlp_json(fetch_tiktok_ytdlp_json(url))
    end

    def fetch_tiktok_ytdlp_json(url)
      return nil unless system('which yt-dlp > /dev/null 2>&1')
      json_str = `yt-dlp -j --no-download --no-warnings "#{url}" 2>/dev/null`
      return nil if json_str.blank?
      JSON.parse(json_str)
    rescue JSON::ParserError, Errno::ENOENT
      nil
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