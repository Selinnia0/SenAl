Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Halka açık: landing ve durum sayfası (giriş gerektirmez)
  root "landing#show"
  get "status", to: "status_pages#show", as: :status_page

  get "dashboard", to: "dashboard#show"

  # v2 response katmanı
  resources :incidents, only: %i[ index show new create ] do
    member do
      post :transition
      patch :severity
    end
    resources :updates, only: :create, controller: "incident_updates"
    resources :status_page_updates, only: :create
    resources :role_assignments, only: :create
    resources :follow_ups, only: :create do
      member { patch :complete }
    end
    resource :postmortem, only: %i[ edit update ] do
      post :publish
    end
  end
  get "post_incident", to: "post_incident#index"

  resources :alerts, only: %i[ index show ] do
    member do
      post :acknowledge
      post :resolve
    end
  end
  resources :schedules, only: %i[ index show ] do
    resources :overrides, only: %i[ create destroy ]
  end
  resources :unavailabilities, only: %i[ index create destroy ]
  resources :notifications, only: :index do
    member { patch :read }
    collection { patch :read_all }
  end

  # Yalnızca manager
  resources :services do
    member { post :test_alert } # arayüzden deneme alarmı (API ile aynı yol: EventIngestor)
  end
  resources :blackout_periods, except: :show
  resource :time_skip, only: %i[ new create ] # demo aracı, bkz. TimeSkip

  # Tasarım sistemi vitrini: yalnızca geliştirme ve test (production'da route yok).
  get "design", to: "design#show" if Rails.env.local?

  namespace :api do
    namespace :v1 do
      resources :events, only: :create
    end
  end
end
