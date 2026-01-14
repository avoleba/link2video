require 'sidekiq/web'

Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq'
  
  namespace :api do
    resources :videos, only: [:create, :show]
  end
  
  # Для проверки работоспособности
  root to: proc { [200, {}, ['Video Bot API']] }
end
