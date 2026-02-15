# frozen_string_literal: true

Rails.application.routes.draw do
  mount RSB::Admin::Engine => '/admin'

  get 'up' => 'rails/health#show', as: :rails_health_check

  root to: proc { [200, {}, ['OK']] }
end
