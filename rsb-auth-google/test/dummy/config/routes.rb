# frozen_string_literal: true

Rails.application.routes.draw do
  mount RSB::Auth::Engine => '/auth'
  mount RSB::Auth::Google::Engine => '/auth/oauth/google'
  root to: proc { [200, {}, ['OK']] }
end
