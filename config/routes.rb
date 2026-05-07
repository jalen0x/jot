Rails.application.routes.draw do
  devise_for :users,
             controllers: {
               omniauth_callbacks: "users/omniauth_callbacks",
               passwords: "users/passwords",
               sessions: "users/sessions"
             }

  devise_scope :user do
    get "users/sign_in/two_factor",
        to: "users/sessions#new_second_factor",
        as: :new_user_second_factor_session

    resource :user_two_factor,
             path: "users/two_factor",
             controller: "users/two_factor",
             only: [ :new, :create, :destroy ]

    resource :user_profile_lock,
             path: "users/profile_lock",
             controller: "users/profile_locks",
             only: [ :show, :create, :destroy ]
  end

  if Rails.env.development?
    mount Lookbook::Engine, at: "/lookbook"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#show"
end
