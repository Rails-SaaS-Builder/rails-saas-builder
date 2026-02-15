# frozen_string_literal: true

RSB::Admin::Engine.routes.draw do
  get  'login',  to: 'sessions#new', as: :login
  post 'login',  to: 'sessions#create'
  get  'login/two_factor', to: 'sessions#two_factor',        as: :two_factor_login
  post 'login/two_factor', to: 'sessions#verify_two_factor', as: :verify_two_factor_login
  delete 'logout', to: 'sessions#destroy', as: :logout

  root to: 'dashboard#index', as: :dashboard

  # Dashboard sub-actions (tab navigation for custom dashboard pages)
  get    'dashboard/:action_key', to: 'dashboard#dashboard_action', as: :dashboard_action,
                                  constraints: { action_key: /[a-z_]+/ }
  post   'dashboard/:action_key', to: 'dashboard#dashboard_action', constraints: { action_key: /[a-z_]+/ }
  patch  'dashboard/:action_key', to: 'dashboard#dashboard_action', constraints: { action_key: /[a-z_]+/ }
  delete 'dashboard/:action_key', to: 'dashboard#dashboard_action', constraints: { action_key: /[a-z_]+/ }

  get   'settings', to: 'settings#index', as: :settings
  patch 'settings', to: 'settings#batch_update'
  patch 'settings/:category/:key', to: 'settings#update', as: :setting

  get   'profile',                      to: 'profile#show',              as: :profile
  get   'profile/edit',                 to: 'profile#edit',              as: :edit_profile
  patch 'profile',                      to: 'profile#update'
  get   'profile/verify_email',         to: 'profile#verify_email', as: :verify_email_profile
  post  'profile/resend_verification',  to: 'profile#resend_verification', as: :resend_verification_profile
  get   'profile/two_factor/new',          to: 'two_factor#new',          as: :new_profile_two_factor
  post  'profile/two_factor',              to: 'two_factor#create',       as: :profile_two_factor
  get   'profile/two_factor/backup_codes', to: 'two_factor#backup_codes', as: :profile_two_factor_backup_codes
  delete 'profile/two_factor',             to: 'two_factor#destroy'
  delete 'profile/sessions',            to: 'profile_sessions#destroy_all', as: :profile_sessions
  delete 'profile/sessions/:id',        to: 'profile_sessions#destroy',     as: :profile_session

  resources :roles
  resources :admin_users

  # Dynamic resource routes for registered resources.
  # These catch-all routes must be LAST so they don't override static routes above.
  # Order matters: specific patterns before generic ':id' patterns.
  get    ':resource_key/new',            to: 'resources#new'
  post   ':resource_key',                to: 'resources#create'

  # Static page sub-actions (must be before catch-all :id routes)
  get    ':resource_key/:action_key', to: 'resources#page_action', constraints: { action_key: /[a-z_]+/ }
  post   ':resource_key/:action_key', to: 'resources#page_action', constraints: { action_key: /[a-z_]+/ }
  delete ':resource_key/:action_key', to: 'resources#page_action', constraints: { action_key: /[a-z_]+/ }
  patch  ':resource_key/:action_key', to: 'resources#page_action', constraints: { action_key: /[a-z_]+/ }

  get    ':resource_key/:id/edit',       to: 'resources#edit'
  patch  ':resource_key/:id',            to: 'resources#update'
  put    ':resource_key/:id',            to: 'resources#update'
  delete ':resource_key/:id',            to: 'resources#destroy'
  get    ':resource_key/:id/:custom_action', to: 'resources#custom_action'
  post   ':resource_key/:id/:custom_action', to: 'resources#custom_action'
  patch  ':resource_key/:id/:custom_action', to: 'resources#custom_action'
  get    ':resource_key/:id',            to: 'resources#show'
  get    ':resource_key',                to: 'resources#index'
end
