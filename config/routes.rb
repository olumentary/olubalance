# frozen_string_literal: true

Rails.application.routes.draw do
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

  authenticated do
    root to: "accounts#index", as: :authenticated_root
  end

  root to: "static_pages#home"
end
