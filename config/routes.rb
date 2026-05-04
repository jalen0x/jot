Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions", omniauth_callbacks: "users/omniauth_callbacks" }

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

  namespace :api do
    namespace :v1 do
      resources :accounts, only: [ :index, :show, :create, :update, :destroy ] do
        resource :reconciliation_statement, only: :show, controller: "account_reconciliation_statements"
      end
      resources :transaction_categories, only: [ :index, :show, :create, :update, :destroy ]
      resources :transaction_tag_groups, only: [ :index, :show, :create, :update, :destroy ]
      resources :transaction_tags, only: [ :index, :show, :create, :update, :destroy ]
      resources :transaction_templates, only: [ :index, :show, :create, :update, :destroy ]
      resource :transaction_count, only: :show
      resource :transaction_statistics, only: :show
      resources :transaction_trends, only: :index
      resources :transaction_deletions, only: :create
      resources :transaction_category_assignments, only: :create
      resources :transaction_account_assignments, only: :create
      resources :transaction_account_moves, only: :create
      resources :transaction_tag_assignments, only: :create
      resources :transaction_tag_removals, only: :create
      resources :transaction_tag_clearances, only: :create
      resources :transactions, only: [ :index, :show, :create, :update, :destroy ] do
        resources :pictures, controller: "transaction_pictures", only: [ :index, :create, :destroy ]
      end
    end
  end

  resource :dashboard, only: :show
  resource :reports, only: :show
  resource :user_preference, only: [ :show, :update ]
  resource :two_factor_authentication, only: [ :show, :create, :destroy ]
  resource :two_factor_challenge, only: [ :new, :create ]
  resource :two_factor_recovery_codes, only: :create
  resource :application_lock, only: [ :show, :create, :destroy ] do
    post :lock
    get :unlock
    post :unlock
  end
  resource :ledger_clearance, only: [ :new, :create ]
  resources :api_tokens, only: [ :index, :create, :destroy ]
  resources :user_custom_exchange_rates, only: [ :index, :create, :destroy ]
  resources :data_exports, only: :create
  resources :import_batches, only: [ :new, :create, :show ]
  resources :transaction_templates, only: [ :index, :new, :create, :destroy ]
  resources :transaction_categories, only: [ :index, :new, :create ]
  resources :transaction_tag_groups, only: [ :index, :new, :create ]
  resources :transaction_tags, only: [ :new, :create ]
  resources :transactions, only: [ :index, :new, :create, :destroy ] do
    resources :pictures, controller: "transaction_pictures", only: :destroy
  end
  resources :accounts, only: [ :index, :new, :create ]

  # Defines the root path route ("/")
  root "home#show"
end
