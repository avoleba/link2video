class TikTokVideoProcessor
  class << self
    def get_video_for_telegram(url)
      video_info = get_tiktok_info(url)
      
      return video_info if video_info[:error]
      
      video_url = extract_tiktok_video_url(video_info[:html], url)
      
      if video_url
        {
          success: true,
          platform: :tiktok,
          title: video_info[:title] || "TikTok Video",
          author: video_info[:author] || "TikTok",
          thumbnail: video_info[:thumbnail],
          video_url: video_url,
          is_video: true,
          watch_url: url,
          message: "TikTok видео готово к просмотру в Telegram"
        }
      else
        { error: "Не удалось получить видео с TikTok" }
      end
    end
    
    private
    
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
    
    
    def extract_meta_content(doc, property)
      meta = doc.at_css("meta[property='#{property}']")
      meta ? meta['content'] : nil
    end
  end
end