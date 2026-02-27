# frozen_string_literal: true

# Cross-Gem Regression: Security Hardening (TDD-016)
#
# Verifies that security fixes work correctly when all engines are mounted
# together: settings registered, resolver locks enforced, generic error
# messages flow through the full stack, admin idle timeout works.

require 'test_helper'

class SecurityHardeningRegressionTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    register_all_admin_categories
    Rails.cache.clear
  end

  teardown do
    RSB::Settings.configuration.instance_variable_get(:@locks)&.clear
    RSB::Admin::AdminSession.delete_all
    RSB::Admin::AdminUser.delete_all
    RSB::Admin::Role.delete_all
    RSB::Admin.reset!
  end

  # --- New settings are registered and accessible ---

  test 'auth.generic_error_messages setting is registered and resolvable' do
    value = RSB::Settings.get('auth.generic_error_messages')
    assert_equal false, value, 'Default for auth.generic_error_messages must be false'
  end

  test 'auth.generic_error_messages can be set and read back' do
    RSB::Settings.set('auth.generic_error_messages', true)
    assert_equal true, RSB::Settings.get('auth.generic_error_messages')

    RSB::Settings.set('auth.generic_error_messages', false)
    assert_equal false, RSB::Settings.get('auth.generic_error_messages')
  end

  test 'admin.session_idle_timeout setting is registered and resolvable' do
    value = RSB::Settings.get('admin.session_idle_timeout')
    assert_equal 0, value, 'Default for admin.session_idle_timeout must be 0'
  end

  test 'admin.session_idle_timeout can be set to a positive integer' do
    RSB::Settings.set('admin.session_idle_timeout', 1800)
    assert_equal 1800, RSB::Settings.get('admin.session_idle_timeout')
  end

  # --- LockedSettingError works via public API ---

  test 'RSB::Settings.set raises LockedSettingError for locked keys' do
    RSB::Settings.configure { |c| c.lock('auth.generic_error_messages') }

    error = assert_raises(RSB::Settings::LockedSettingError) do
      RSB::Settings.set('auth.generic_error_messages', true)
    end
    assert_match(/locked/, error.message)
  end

  test 'LockedSettingError does not affect unlocked settings' do
    RSB::Settings.configure { |c| c.lock('auth.generic_error_messages') }

    # Unlocked setting should work fine
    RSB::Settings.set('admin.session_idle_timeout', 600)
    assert_equal 600, RSB::Settings.get('admin.session_idle_timeout')
  end

  # --- New settings appear in admin settings page ---

  test 'new security settings visible on admin settings page' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    # Check auth tab for generic_error_messages
    get rsb_admin.settings_path(tab: 'auth')
    assert_response :success
    assert_match(/generic_error_messages/i, response.body,
      'auth.generic_error_messages must appear on auth settings tab')

    # Check admin tab for session_idle_timeout
    get rsb_admin.settings_path(tab: 'admin')
    assert_response :success
    assert_match(/session_idle_timeout/i, response.body,
      'admin.session_idle_timeout must appear on admin settings tab')
  end

  # --- Full login flow with generic errors enabled ---

  test 'full login flow with generic_error_messages enabled returns generic errors' do
    identity = create_test_identity
    create_test_credential(identity: identity, email: 'regression@example.com')

    RSB::Settings.set('auth.generic_error_messages', true)

    # Suspended identity
    identity.update!(status: :suspended)
    post session_path, params: { identifier: 'regression@example.com', password: 'password1234' }
    assert_match(/Invalid credentials/i, response.body)
    assert_no_match(/suspended/i, response.body)
  end

  # --- Admin idle timeout with full stack ---

  test 'admin idle timeout works with full engine stack' do
    RSB::Settings.set('admin.session_idle_timeout', 300) # 5 minutes

    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    # Set last_active_at to past
    admin_session = RSB::Admin::AdminSession.last
    admin_session.update_column(:last_active_at, 6.minutes.ago)

    # Access dashboard — should expire and redirect to login
    get rsb_admin.dashboard_path
    assert_redirected_to rsb_admin.login_path
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
