class InstagramVideoProcessor
  class << self
    def get_video_for_telegram(url)
      # Получаем информацию о посте
      video_info = get_instagram_info(url)
      
      return video_info if video_info[:error]
      
      # Получаем прямую ссылку на видео
      video_url = decode_instagram_url(extract_video_url(video_info[:html], url))
      
      if video_url
        {
          success: true,
          platform: :instagram,
          title: video_info[:title] || "Instagram Video",
          author: video_info[:author] || "Instagram",
          thumbnail: video_info[:thumbnail],
          video_url: video_url,  # Прямая ссылка на видео файл
          is_video: true,
          watch_url: url,  # Оригинальная ссылка
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
    
    def extract_video_url(html, original_url)
      # Парсим JSON данные Instagram
      # Instagram хранит информацию в window.__additionalDataLoaded
      
      # Вариант 1: Ищем video_url в JSON
      if html.include?('video_url')
        match = html.match(/"video_url":"([^"]+)"/)
        return match[1].gsub('\\u0026', '&') if match
      end
      
      # Вариант 2: Ищем в структуре данных
      if html.include?('"video_versions"')
        match = html.match(/"video_versions":\[.*?"url":"([^"]+)"/m)
        return match[1].gsub('\\u0026', '&') if match
      end
      
      # Вариант 3: Используем сторонний сервис
      # Например: https://igram.io/api/
      # Или: https://rapidapi.com/ (требует API ключ)
      
      nil
    end

    def decode_instagram_url(encoded_url)
      # Убираем все escape-последовательности
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
        
        # Убираем стандартные порты
        if (uri.scheme == 'https' && uri.port == 443) || 
           (uri.scheme == 'http' && uri.port == 80)
          uri.port = nil
        end
        
        # Проверяем, что хост есть
        return nil unless uri.host
        
        # Возвращаем исправленный URL
        uri.to_s
        
      rescue URI::InvalidURIError => e
        # Пробуем простое исправление
        fixed = url
          .gsub(/:443/, '')  # Убираем порт 443
          .gsub(/:80/, '')   # Убираем порт 80
        
        # Проверяем, что это валидный URL
        if fixed =~ /\Ahttps?:\/\//
          fixed
        else
          nil
        end
      end
    end
    
    def extract_video_url(html, original_url)
      # Ищем video_url в JSON
      if html.include?('video_url')
        # Ищем все совпадения
        matches = html.scan(/"video_url":"([^"]+)"/)
        
        puts "Найдено #{matches.size} video_url в HTML"
        
        # Берем последнее совпадение (обычно это самое актуальное)
        if matches.any?
          encoded_url = matches.last[0]
          puts "Найден URL (закодированный): #{encoded_url[0..100]}..."
          
          decoded_url = decode_instagram_url(encoded_url)
          puts "Декодированный URL: #{decoded_url[0..100]}..." if decoded_url
          
          return decoded_url
        end
      end
      
      # Пробуем другие методы поиска
      [
        /"video_url":"([^"]+)"/,
        /"video_versions":\[.*?"url":"([^"]+)"/m,
        /"video_dash_manifest":"([^"]+)"/,
        /property="og:video" content="([^"]+)"/
      ].each do |pattern|
        match = html.match(pattern)
        if match
          encoded_url = match[1]
          puts "Найден по паттерну: #{encoded_url[0..100]}..."
          
          decoded_url = decode_instagram_url(encoded_url)
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