# frozen_string_literal: true

# Обработка Instagram-ссылок и подготовка видео для отправки в Telegram
class InstagramVideoProcessor
  class << self
    # @param url [String]
    # @return [Hash{Symbol => Object}]
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

    # @param url [String]
    # @return [Hash{Symbol => Object}]
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
    rescue StandardError => e
      { error: "Instagram ошибка: #{e.message}" }
    end

    # @param encoded_url [String]
    # @return [String, nil]
    def decode_instagram_url(encoded_url)
      decoded = encoded_url
                .gsub('\\/', '/')
                .gsub('\\u0026', '&')
                .gsub('\\u00253D', '=')
                .gsub('\\u003D', '=')
                .gsub('\\u0025', '%')
                .gsub('\\\\', '')

      decoded = URI.decode_www_form_component(decoded)

      fix_instagram_url(decoded)
    end

    # @param url [String]
    # @return [String, nil]
    def fix_instagram_url(url)
      uri = URI.parse(url)

      if (uri.scheme == 'https' && uri.port == 443) ||
         (uri.scheme == 'http' && uri.port == 80)
        uri.port = nil
      end

      return nil unless uri.host

      uri.to_s
    rescue URI::InvalidURIError
      fixed = url.gsub(/:443/, '').gsub(/:80/, '')

      fixed =~ /\Ahttps?:\/\// ? fixed : nil
    end

    # @param html [String]
    # @param original_url [String]
    # @return [String, nil]
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

    # @param doc [Nokogiri::HTML::Document]
    # @param property [String]
    # @return [String, nil]
    def extract_meta_content(doc, property)
      meta = doc.at_css("meta[property='#{property}']")
      meta ? meta['content'] : nil
    end
  end
end
