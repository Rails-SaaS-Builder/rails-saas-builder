source "https://rubygems.org"

gemspec

gem "rsb-settings",      path: "rsb-settings"
gem "rsb-auth",          path: "rsb-auth"
gem "rsb-entitlements",  path: "rsb-entitlements"
gem "rsb-entitlements-stripe", path: "rsb-entitlements-stripe"
gem "rsb-admin",         path: "rsb-admin"

group :development, :test do
  gem "ostruct"
  gem "rubocop-rails-omakase", require: false
  gem "sqlite3"
  gem "puma"
  gem "propshaft"
end

group :development do
  gem "letter_opener"
end
