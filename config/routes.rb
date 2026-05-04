Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions", omniauth_callbacks: "users/omniauth_callbacks" }

  if Rails.env.development?
    mount Lookbook::Engine, at: "/lookbook"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  namespace :api do
    namespace :v1 do
      resources :accounts, only: [ :index, :show, :create, :update, :destroy ] do
        resource :reconciliation_statement, only: :show, controller: "account_reconciliation_statements"
      end
      resources :account_balance_trends, only: :index
      resource :user_preference, only: [ :show, :update ]
      resource :user_profile, only: [ :show, :update ]
      resource :user_avatar, only: [ :create, :destroy ]
      resource :system_version, only: :show
      resource :exchange_rate_catalog, only: :show
      resource :application_lock, only: [ :show, :create, :destroy ]
      resource :two_factor_setup, only: :create
      resource :two_factor_authentication, only: [ :show, :create, :destroy ]
      resource :two_factor_recovery_codes, only: :create
      resources :api_tokens, only: [ :index, :create, :destroy ]
      resources :external_authentications, only: [ :index, :destroy ]
      resources :user_custom_exchange_rates, only: [ :index, :show, :create, :update, :destroy ]
      resource :data_statistics, only: :show
      resources :data_exports, only: :create
      resources :import_batches, only: [ :show, :create ]
      resources :receipt_recognitions, only: [ :show, :create ]
      resources :ledger_clearances, only: :create
      resources :insight_explorers, only: [ :index, :show, :create, :update, :destroy ]
      resources :transaction_categories, only: [ :index, :show, :create, :update, :destroy ]
      resources :transaction_tag_groups, only: [ :index, :show, :create, :update, :destroy ]
      resources :transaction_tags, only: [ :index, :show, :create, :update, :destroy ]
      resources :transaction_templates, only: [ :index, :show, :create, :update, :destroy ]
      resource :transaction_count, only: :show
      resource :transaction_amount_summary, only: :show
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
  resource :data_management, only: :show
  resource :user_profile, only: [ :show, :update ]
  resource :user_avatar, only: [ :create, :destroy ]
  resource :user_preference, only: [ :show, :update ]
  resource :two_factor_authentication, only: [ :show, :create, :destroy ]
  resource :two_factor_challenge, only: [ :new, :create ]
  resource :two_factor_recovery_codes, only: :create
  resource :application_lock, only: [ :show, :create, :destroy ]
  resource :application_lock_session, only: [ :new, :create, :destroy ]
  resource :ledger_clearance, only: [ :new, :create ]
  resources :api_tokens, only: [ :index, :create, :destroy ]
  resources :external_authentications, only: [ :index, :destroy ]
  resources :user_custom_exchange_rates, only: [ :index, :create, :edit, :update, :destroy ]
  resources :data_exports, only: :create
  resources :import_batches, only: [ :new, :create, :show ]
  resources :insight_explorers, only: [ :index, :new, :create, :edit, :update, :destroy ]
  resources :transaction_templates, only: [ :index, :new, :create, :edit, :update, :destroy ]
  resources :receipt_recognitions, only: [ :new, :create, :show ]
  resources :transaction_categories, only: [ :index, :new, :create, :edit, :update, :destroy ]
  resources :transaction_tag_groups, only: [ :index, :new, :create, :edit, :update, :destroy ]
  resources :transaction_tags, only: [ :new, :create, :edit, :update, :destroy ]
  resources :transactions, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    resources :pictures, controller: "transaction_pictures", only: :destroy
  end
  resources :accounts, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    resource :reconciliation_statement, only: :show, controller: "account_reconciliation_statements"
  end

  # Defines the root path route ("/")
  root "home#show"
end
