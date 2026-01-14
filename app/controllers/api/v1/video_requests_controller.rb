# app/controllers/api/v1/video_requests_controller.rb
module Api
  module V1
    class VideoRequestsController < ApplicationController
      def create
        request = VideoRequest.create!(video_request_params)
        
        # Обрабатываем асинхронно
        VideoProcessorJob.perform_later(request.id)
        
        render json: {
          message: 'Запрос принят в обработку',
          request_id: request.id,
          status_url: api_v1_video_request_url(request)
        }
      end
      
      def show
        request = VideoRequest.find(params[:id])
        
        render json: {
          request: request,
          video_info: request.raw_data,
          download_url: request.video_url
        }
      end
      
      private
      
      def video_request_params
        params.require(:video_request).permit(:url, :user_id)
      end
    end
  end
end