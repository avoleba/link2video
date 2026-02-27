class InstagramVideoProcessor
  class << self
    def get_video_for_telegram(url)
      video_info = get_instagram_info(url)
      
      return video_info if video_info[:error]
      
      video_url = decode_instagram_url(extract_video_url(video_info[:html], url))
      
      if video_url
        {
          success: true,
          platform: :instagram,
          title: video_info[:title] || "Instagram Video",
          author: video_info[:author] || "Instagram",
          thumbnail: video_info[:thumbnail],
          video_url: video_url,
          is_video: true,
          watch_url: url,
          message: "Instagram видео готово к просмотру в Telegram"
        }
      else
        { error: "Не удалось получить видео с Instagram" }
      end
    end
    
    private
    
    def get_instagram_info(url)
      headers = {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
      
      response = HTTParty.get(url, headers: headers, follow_redirects: true)
      
      if response.success?
        html = response.body
        doc = Nokogiri::HTML(html)
        
        {
          html: html,
          title: extract_meta_content(doc, 'og:title'),
          author: extract_meta_content(doc, 'og:site_name'),
          thumbnail: extract_meta_content(doc, 'og:image'),
          description: extract_meta_content(doc, 'og:description')
        }
      else
        { error: "Не удалось загрузить страницу Instagram" }
      end
    rescue => e
      { error: "Instagram ошибка: #{e.message}" }
    end
    
    def decode_instagram_url(encoded_url)
      decoded = encoded_url
        .gsub('\\/', '/')          # Убираем экранирование слешей
        .gsub('\\u0026', '&')      # Декодируем & из unicode
        .gsub('\\u00253D', '=')    # Декодируем = (двойное кодирование)
        .gsub('\\u003D', '=')      # Декодируем = из unicode
        .gsub('\\u0025', '%')      # Декодируем %
        .gsub('\\\\', '')          # Убираем лишние обратные слеши
      
      # Декодируем URL-encoded символы
      decoded = URI.decode_www_form_component(decoded)
      
      # Проверяем и исправляем порт
      fix_instagram_url(decoded)
    end
    
    def fix_instagram_url(url)
      begin
        uri = URI.parse(url)
        
        if (uri.scheme == 'https' && uri.port == 443) || 
           (uri.scheme == 'http' && uri.port == 80)
          uri.port = nil
        end
        
        return nil unless uri.host
        
        uri.to_s
        
      rescue URI::InvalidURIError => e
        fixed = url.gsub(/:443/, '').gsub(/:80/, '')
        
        fixed =~ /\Ahttps?:\/\// ? fixed : nil
      end
    end
    
    def extract_video_url(html, original_url)
      if html.include?('video_url')
        matches = html.scan(/"video_url":"([^"]+)"/)
                
        if matches.any?
          encoded_url = matches.last[0]
          return decode_instagram_url(encoded_url)
        end
      end
      
      [
        /"video_url":"([^"]+)"/,
        /"video_versions":\[.*?"url":"([^"]+)"/m,
        /"video_dash_manifest":"([^"]+)"/,
        /property="og:video" content="([^"]+)"/
      ].each do |pattern|
        match = html.match(pattern)
        if match
          decoded_url = decode_instagram_url(match[1])
          return decoded_url if decoded_url
        end
      end
      
      nil
    end
    
    def extract_meta_content(doc, property)
      meta = doc.at_css("meta[property='#{property}']")
      meta ? meta['content'] : nil
    end
  end
end