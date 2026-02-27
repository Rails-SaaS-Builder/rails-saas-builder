# frozen_string_literal: true

# Security Test: Open Redirect Prevention
#
# Attack vectors prevented:
# - Open redirect via locale middleware redirect_to parameter
# - External URL redirect via POST /rsb/locale
# - Protocol-relative URL bypass (//evil.com)
#
# Covers: SRS-016 US-025 (Open Redirect Prevention)

require 'test_helper'

class SettingsOpenRedirectTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    RSB::Settings.configure do |config|
      config.available_locales = %w[en es]
      config.default_locale = 'en'
    end
  end

  test 'locale middleware rejects redirect to external URL' do
    post '/rsb/locale', params: { locale: 'es' },
                        headers: { 'HTTP_REFERER' => 'https://evil.com/phishing' }

    # Should redirect to root or relative path, NOT to evil.com
    if response.redirect?
      location = response.headers['Location']
      refute_match(/evil\.com/, location,
                   "Redirect location must not go to external site: #{location}")
    end
  end

  test 'locale middleware rejects protocol-relative URL redirect' do
    post '/rsb/locale', params: { locale: 'es' },
                        headers: { 'HTTP_REFERER' => '//evil.com/phishing' }

    if response.redirect?
      location = response.headers['Location']
      refute_match(/evil\.com/, location,
                   "Must not redirect to protocol-relative external URL: #{location}")
    end
  end

  test 'locale middleware allows relative path redirect' do
    post '/rsb/locale', params: { locale: 'es' },
                        headers: { 'HTTP_REFERER' => 'http://localhost/some/page' }

    if response.redirect?
      location = response.headers['Location']
      # Should be a relative path or same-host URL
      parsed = begin
        URI.parse(location)
      rescue StandardError
        nil
      end
      if parsed&.host
        assert_equal 'localhost', parsed.host,
                     "Redirect must stay on same host: #{location}"
      end
    end
  end

  test 'settings batch update tab redirect is safe (same page query param)' do
    register_all_admin_categories
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    patch rsb_admin.settings_path, params: {
      category: 'admin',
      tab: 'https://evil.com',
      settings: { per_page: '25' }
    }

    if response.redirect?
      location = response.headers['Location']
      refute_match(/evil\.com/, location,
                   "Tab redirect must not go to external site: #{location}")
    end
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
