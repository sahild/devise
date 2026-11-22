Rails.application.routes.draw do
  devise_for :users

  authenticate :user do
    get "dashboard", to: "home#dashboard"
  end

  root "home#index"
end
