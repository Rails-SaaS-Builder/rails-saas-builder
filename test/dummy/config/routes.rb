Rails.application.routes.draw do
  mount RSB::Auth::Engine => '/auth'
  mount RSB::Admin::Engine => '/admin'

  # Letter Opener Web for email preview in development
  # mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  get 'up' => 'rails/health#show', as: :rails_health_check

  root to: proc { [200, {}, ['OK']] }
end
