# frozen_string_literal: true

class VideoRequestRepository
  include Aux::Pluggable

  register initialize: true, memoize: true

  # @param platform [Appointment]
  # @return [VideoRequest]
  def find_or_create_by(url:, **attributes)
    platform = detect_platform(url.to_s)
    raise(ArgumentError, "Unsupported platform: #{platform.to_s}") if platform == :unknown

    request = data_gateway.find_or_create_by(platform: platform, url: url, **attributes.except(:status))
    request.update(status: attributes[:status]) if attributes[:status]
    request
  end

  private

  # @param url [String]
  # @return [String]
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

  # @return [Class<VideoRequest>]
  def data_gateway
    VideoRequest
  end
end
