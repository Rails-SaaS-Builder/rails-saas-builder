# frozen_string_literal: true

RSB::Auth::Google::Engine.routes.draw do
  get '/', to: 'oauth#redirect', as: :google_oauth_redirect
  get '/callback', to: 'oauth#callback', as: :google_oauth_callback
end
