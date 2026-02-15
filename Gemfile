# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rsb-admin',         path: 'rsb-admin'
gem 'rsb-auth',          path: 'rsb-auth'
gem 'rsb-entitlements',  path: 'rsb-entitlements'
gem 'rsb-entitlements-stripe', path: 'rsb-entitlements-stripe'
gem 'rsb-settings', path: 'rsb-settings'

group :development, :test do
  gem 'ostruct'
  gem 'propshaft'
  gem 'puma'
  gem 'rubocop-rails-omakase', require: false
  gem 'sqlite3'
end

group :development do
  gem 'letter_opener'
end
