# frozen_string_literal: true

class VideoProcessorJob < ActiveJob::Base
  queue_as :default

  # @param request_id [Integer]
  # @param processing_message_id [Integer, nil]
  # @return [void]
  def perform(request_id, processing_message_id = nil)
    request = VideoRequest.find(request_id)
    return unless request

    request.update!(status: :processing)

    video_info = VideoDownloader.get_video_info(request.platform, request.url)

    if video_info[:error]
      request.update!(status: :failed, error_message: video_info[:error])
      TelegramResultSender.send_error(
        request: request,
        error: video_info[:error],
        processing_message_id: processing_message_id
      )
    else
      request.update!(
        status: :completed,
        title: video_info[:title],
        author: video_info[:author],
        duration: video_info[:duration],
        thumbnail_url: video_info[:thumbnail],
        video_url: video_info[:video_url],
        platform: (video_info[:platform]&.to_sym || :unknown)
      )
      TelegramResultSender.send_success(
        request: request,
        video_info: video_info,
        processing_message_id: processing_message_id
      )
    end
  end
end
