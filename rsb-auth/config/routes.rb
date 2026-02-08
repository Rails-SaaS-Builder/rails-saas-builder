RSB::Auth::Engine.routes.draw do
  resource :registration, only: [:new, :create]
  resource :session, only: [:new, :create, :destroy]

  get  "verify/:token", to: "verifications#show", as: :verification
  post "verify",        to: "verifications#create", as: :send_verification

  resources :password_resets, only: [:new, :create, :edit, :update], param: :token

  resource :account, only: [:show, :update], controller: "account" do
    get :confirm_destroy
    delete "/", to: "account#destroy", as: :destroy_account

    scope module: :account do
      resources :login_methods, only: [:show, :destroy] do
        member do
          patch :password, to: "login_methods#change_password"
          post :resend_verification
        end
      end

      resources :sessions, only: [:destroy] do
        collection do
          delete "/", to: "sessions#destroy_all", as: :destroy_all
        end
      end
    end
  end

  get   "invitations/:token", to: "invitations#show",   as: :accept_invitation
  patch "invitations/:token", to: "invitations#update"
end
