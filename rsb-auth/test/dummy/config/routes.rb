Rails.application.routes.draw do
  mount RSB::Auth::Engine => "/auth"

  get "up" => "rails/health#show", as: :rails_health_check

  root to: "home#index"
end
