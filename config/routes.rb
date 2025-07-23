# frozen_string_literal: true

Rails.application.routes.draw do
  # Rails 7.1+ health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  devise_scope :user do
    get "/sign_in" => "devise/sessions#new"
  end

  devise_for :users, skip: [ :registrations ], controllers: { registrations: "registrations" }

  as :user do
    get "users/edit" => "devise/registrations#edit", :as => "edit_user_registration"
    patch "users/:id" => "devise/registrations#update", :as => "user_registration"
  end

  get "accounts/inactive" => "accounts#inactive"
  get "accounts/summary" => "summary#index"
  post "accounts/summary/mail" => "summary#send_mail"

  resources :accounts, except: %i[show] do
    resources :transactions do
      member do
        patch :mark_reviewed
        patch :mark_pending
        patch :update_attachment
        post :update_date
      end
      collection do
        get :descriptions
      end
    end
    resources :stashes do
      scope except: %i[index show edit update destroy] do
        resources :stash_entries
      end
    end

    member do
      get :deactivate
      get :activate
    end
  end

  resources :transfers, only: %i[create]

  resources :quick_transactions, only: [ :new, :create ]

  authenticated do
    root to: "accounts#index", as: :authenticated_root
  end

  root to: "devise/sessions#new"
end
