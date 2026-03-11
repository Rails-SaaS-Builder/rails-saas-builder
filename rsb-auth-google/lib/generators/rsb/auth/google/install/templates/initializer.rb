# frozen_string_literal: true

# RSB Auth Google configuration
# See: https://github.com/Rails-SaaS-Builder/rails-saas-builder

RSB::Auth::Google.configure do |config|
  # Google OAuth credentials from Google Cloud Console
  # Get yours at: https://console.cloud.google.com/apis/credentials
  #
  # You can also set these via:
  #   - Admin panel: Settings > Google OAuth
  #   - ENV: RSB_AUTH_CREDENTIALS_GOOGLE_CLIENT_ID
  #   - ENV: RSB_AUTH_CREDENTIALS_GOOGLE_CLIENT_SECRET
  #   - RSB::Settings.set('auth.credentials.google.client_id', 'xxx')

  # config.client_id = 'your-client-id.apps.googleusercontent.com'
  # config.client_secret = 'GOCSPX-your-client-secret'
end

# Optional: configure Google OAuth settings via RSB::Settings
# RSB::Settings.set('auth.credentials.google.auto_merge_by_email', true)
# RSB::Settings.set('auth.credentials.google.enabled', true)
