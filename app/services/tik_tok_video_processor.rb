# frozen_string_literal: true

# Обработка TikTok-ссылок и подготовка видео для отправки в Telegram
class TikTokVideoProcessor
  class << self
    # @param url [String]
    # @return [Hash{Symbol => Object}]
    def get_video_for_telegram(url)
      video_info = get_tiktok_info(url)

      return video_info if video_info[:error]

      if video_info[:video_url]
        {
          success: true,
          platform: :tiktok,
          title: video_info[:title] || "TikTok Video",
          author: video_info[:author] || "TikTok",
          thumbnail: video_info[:thumbnail],
          video_url: video_info[:video_url],
          is_video: true,
          watch_url: url,
          message: "TikTok видео готово к просмотру в Telegram"
        }
      else
        { error: "Не удалось получить видео с TikTok" }
      end
    end

    private

    # @param url [String]
    # @return [Hash{Symbol => Object}]
    def get_tiktok_info(url)
      video_data = nil

      video_data = fetch_via_tiktok_api(url)
      video_data = fetch_via_mobile(url) if video_data.blank?
      video_data = fetch_via_ytdlp(url) if video_data.blank?
      video_data = fetch_via_browser_emulation(url) if video_data.blank?

      return { error: "Не удалось загрузить видео с TikTok" } if video_data.blank?

      video_data
    rescue StandardError => e
      { error: "TikTok ошибка: #{e.message}" }
    end

    # @param url [String]
    # @return [Hash{Symbol => Object}, nil]
    def fetch_via_tiktok_api(url)
      video_id = extract_tiktok_video_id(url)
      return nil unless video_id

      api_urls = [
        "https://www.tiktok.com/api/item/detail/?itemId=#{video_id}",
        "https://api16-normal-c-useast1a.tiktokv.com/aweme/v1/aweme/detail/?aweme_id=#{video_id}"
      ]

      api_urls.each do |api_url|
        response = HTTParty.get(api_url, headers: api_headers, timeout: 10)

        if response.success?
          data = response.parsed_response

          if data.is_a?(Hash)
            video_url = extract_video_url_from_api_response(data)
            temp_file = download_video_now(video_url)
            p temp_file

            if temp_file
              return {
                platform: :tiktok,
                title: extract_title_from_api(data),
                author: extract_author_from_api(data),
                thumbnail: extract_thumbnail_from_api(data),
                video_url: temp_file.path,
                duration: extract_duration_from_api(data)
              }
            end
          end
        end
      rescue StandardError => e
        Rails.logger.warn("fetch_via_tiktok_api: #{e.message}")
        next
      end

      nil
    end

    # @param url [String]
    # @return [Hash{Symbol => Object}, nil]
    def fetch_via_mobile(url)
      mobile_headers = {
        'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language' => 'en-US,en;q=0.9',
        'Connection' => 'keep-alive'
      }

      response = HTTParty.get(url, headers: mobile_headers, follow_redirects: true, timeout: 15)
      return nil unless response.success?

      video_url = extract_video_from_html(response.body)
      return nil unless video_url
      temp_file = download_video_now(video_url)

      doc = Nokogiri::HTML(response.body)

      {
        platform: :tiktok,
        title: extract_title_from_html(doc) || "TikTok Video",
        author: extract_author_from_html(doc),
        thumbnail: extract_thumbnail_from_html(doc),
        video_url: temp_file.path,
        is_video: true
      }
    end

    # @param url [String]
    # @return [Hash{Symbol => Object}, nil]
    def fetch_via_ytdlp(url)
      return nil unless system('which yt-dlp > /dev/null 2>&1')

      begin
        json_str = `yt-dlp -j --no-playlist --no-warnings "#{url}" 2>/dev/null`
        return nil if json_str.blank?

        data = JSON.parse(json_str)

        video_url = data['url'] || data.dig('requested_downloads', 0, 'url')
        return nil unless video_url
        temp_file = download_video_now(video_url)
        p temp_file

        {
          platform: :tiktok,
          title: data['title'] || data['fulltitle'] || "TikTok Video",
          author: data['uploader'] || data['creator'] || data['uploader_id'],
          thumbnail: data['thumbnail'],
          video_url: temp_file.path,
          duration: data['duration'],
          is_video: true
        }
      rescue StandardError => e
        Rails.logger.warn("fetch_via_ytdlp: #{e.message}")
        nil
      end
    end

    # @param url [String]
    # @return [Hash{Symbol => Object}, nil]
    def fetch_via_browser_emulation(url)
      services = ["https://tikmate.cc/download?url=#{url}", "https://snaptik.app/download?url=#{url}"]

      services.each do |service_url|
        response = HTTParty.get(service_url, headers: browser_headers, timeout: 15)
        next unless response.success?

        video_match = response.body.match(/https?:[^"'\s]+\.mp4[^"'\s]*/)
        temp_file = download_video_now(video_match[0])

        if video_match
          return {
            platform: :tiktok,
            title: "TikTok Video",
            video_url: temp_file.path,
            is_video: true
          }
        end
      rescue StandardError
        next
      end

      nil
    end

    # @param url [String]
    # @return [String, nil]
    def extract_tiktok_video_id(url)
      patterns = [
        %r{/video/(\d+)},
        %r{/v/(\d+)},
        %r{/(\d+)(?:\?|$)},
        %r{tiktok\.com/@[\w.-]+/video/(\d+)},
        %r{vm\.tiktok\.com/(\w+)}
      ]

      patterns.each do |pattern|
        match = url.match(pattern)
        return match[1] if match
      end

      nil
    end

    # @param data [Hash]
    # @return [String, nil]
    def extract_video_url_from_api_response(data)
      paths = [
        ['itemInfo', 'itemStruct', 'video', 'playAddr'],
        ['item_info', 'item_struct', 'video', 'play_addr'],
        ['aweme_detail', 'video', 'play_addr'],
        ['itemList', 0, 'video', 'playAddr'],
        ['video', 'play_addr']
      ]

      paths.each do |path|
        value = data.dig(*path)
        if value.is_a?(Hash)
          url_list = value['url_list'] || value['urlList']
          return url_list.first if url_list.is_a?(Array) && url_list.any?
        elsif value.is_a?(String)
          return value
        end
      end

      nil
    end

    # @param data [Hash]
    # @return [String, nil]
    def extract_title_from_api(data)
      paths = [
        ['itemInfo', 'itemStruct', 'desc'],
        ['item_info', 'item_struct', 'desc'],
        ['aweme_detail', 'desc'],
        ['itemList', 0, 'desc']
      ]

      paths.each do |path|
        title = data.dig(*path)
        return title if title.present?
      end

      nil
    end

    # @param data [Hash]
    # @return [String, nil]
    def extract_author_from_api(data)
      paths = [
        ['itemInfo', 'itemStruct', 'author', 'uniqueId'],
        ['item_info', 'item_struct', 'author', 'unique_id'],
        ['aweme_detail', 'author', 'unique_id'],
        ['itemList', 0, 'author', 'uniqueId']
      ]

      paths.each do |path|
        author = data.dig(*path)
        return "@#{author}" if author.present?
      end

      nil
    end

    # @param data [Hash]
    # @return [String, nil]
    def extract_thumbnail_from_api(data)
      paths = [
        ['itemInfo', 'itemStruct', 'video', 'cover', 'url_list', 0],
        ['item_info', 'item_struct', 'video', 'cover', 'url_list', 0],
        ['aweme_detail', 'video', 'cover', 'url_list', 0],
        ['itemList', 0, 'video', 'cover', 'urlList', 0]
      ]

      paths.each do |path|
        thumbnail = data.dig(*path)
        return thumbnail if thumbnail.present?
      end

      nil
    end

    # @param data [Hash]
    # @return [Integer, nil]
    def extract_duration_from_api(data)
      paths = [
        ['itemInfo', 'itemStruct', 'video', 'duration'],
        ['item_info', 'item_struct', 'video', 'duration'],
        ['aweme_detail', 'video', 'duration'],
        ['itemList', 0, 'video', 'duration']
      ]

      paths.each do |path|
        duration = data.dig(*path)
        return duration.to_i if duration.present?
      end

      nil
    end

    # @param html [String]
    # @return [String, nil]
    def extract_video_from_html(html)
      patterns = [
        /"videoUrl":\s*"([^"]+)"/,
        /"playAddr":\s*"([^"]+)"/,
        /"src":\s*"([^"]+\.mp4[^"]*)"/,
        /<video[^>]+src="([^"]+\.mp4[^"]*)"/
      ]

      patterns.each do |pattern|
        match = html.match(pattern)
        return decode_json_string(match[1]) if match
      end

      nil
    end

    # @param doc [Nokogiri::HTML::Document]
    # @return [String, nil]
    def extract_title_from_html(doc)
      doc.at_css("meta[property='og:title']")&.[]('content') ||
        doc.at_css("meta[name='title']")&.[]('content') ||
        doc.at_css("title")&.text
    end

    # @param doc [Nokogiri::HTML::Document]
    # @return [String, nil]
    def extract_author_from_html(doc)
      author_meta = doc.at_css("meta[name='author']")&.[]('content')
      return author_meta if author_meta

      og_title = doc.at_css("meta[property='og:title']")&.[]('content')
      if og_title && og_title.include?(' on TikTok')
        return og_title.split(' on TikTok').first
      end

      nil
    end

    # @param doc [Nokogiri::HTML::Document]
    # @return [String, nil]
    def extract_thumbnail_from_html(doc)
      doc.at_css("meta[property='og:image']")&.[]('content') ||
        doc.at_css("meta[name='twitter:image']")&.[]('content')
    end

    # @param str [String, nil]
    # @return [String, nil]
    def decode_json_string(str)
      return nil unless str

      decoded = str.gsub('\u002F', '/')
                   .gsub('\u0026', '&')
                   .gsub('\u003d', '=')
                   .gsub('\u003D', '=')

      decoded.gsub(/\\u([0-9a-fA-F]{4})/) { |_| [::Regexp.last_match(1).hex].pack('U') }
    end

    # @param url [String]
    # @return [Tempfile, nil]
    def download_video_now(url)
      temp_file = Tempfile.new(['tiktok', '.mp4'])
      temp_file.binmode

      URI.open(url,
               "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15",
               "Referer" => "https://www.tiktok.com/",
               "Accept" => "*/*") { |video| temp_file.write(video.read) }

      temp_file.rewind
      temp_file
    rescue StandardError => e
      puts "Download failed: #{e.message}"
      temp_file.close if temp_file
      temp_file.unlink if temp_file
      nil
    end

    # @return [Hash{String => String}]
    def api_headers
      {
        'User-Agent' => 'com.zhiliaoapp.musically/2022600030 (Linux; U; Android 7.1.2; en_US; PBEM00; Build/N2G48H; Cronet/58.0.2991.0)',
        'Accept' => 'application/json',
        'Accept-Language' => 'en-US,en;q=0.9',
        'Connection' => 'keep-alive'
      }
    end

    # @return [Hash{String => String}]
    def browser_headers
      {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language' => 'en-US,en;q=0.5',
        'Accept-Encoding' => 'gzip, deflate, br',
        'Connection' => 'keep-alive',
        'Upgrade-Insecure-Requests' => '1'
      }
    end
  end
end
