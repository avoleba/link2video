# frozen_string_literal: true

# app/controllers/api/v1/video_requests_controller.rb
module Api
  module V1
    class VideoRequestsController < ActionController::API
      include Aux::Pluggable

      # @return [void]
      def create
        request = video_request_repository.find_or_create_by(video_request_params)

        VideoProcessorJob.perform_later(request.id)

        render json: {
          message: 'Запрос принят в обработку',
          request_id: request.id,
          status_url: api_v1_video_request_url(request)
        }
      end

      # @return [void]
      def show
        request = VideoRequest.find(params[:id])

        render json: {
          request: request,
          video_info: request.raw_data,
          download_url: request.video_url
        }
      end

      private

      # @return [ActionController::Parameters]
      def video_request_params
        params.require(:video_request).permit(:url, :user_id)
      end

      # @!attribute [r] video_request_repository
      #   @return [VideoRequestRepository]
      resolve :video_request_repository, scope: nil
    end
  end
end
