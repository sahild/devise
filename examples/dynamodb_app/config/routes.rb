Rails.application.routes.draw do
  devise_for :users

  get "account", to: "home#account", as: :account
  root "home#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
