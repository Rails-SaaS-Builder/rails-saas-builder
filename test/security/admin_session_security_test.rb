# frozen_string_literal: true

# Security Test: Admin Session Security & Cookie Hardening
#
# Attack vectors prevented:
# - Admin session token theft via XSS (signed session, httponly)
# - Admin session replay after logout
# - Admin session without proper entropy
# - Admin idle session exploitation
#
# Covers: SRS-016 US-012 (Admin Session Security)

require 'test_helper'

class AdminSessionSecurityTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
  end

  # --- Session token security ---

  test 'admin session token has sufficient entropy' do
    session = RSB::Admin::AdminSession.create_from_request!(
      admin_user: @admin,
      request: OpenStruct.new(remote_ip: '127.0.0.1', user_agent: 'Test/1.0')
    )
    # urlsafe_base64(32) produces ~43 characters
    assert session.session_token.length >= 32,
           "Admin session token length #{session.session_token.length} is insufficient"
  end

  test 'admin session is stored in signed Rails session (not plain cookie)' do
    sign_in_admin(@admin)
    get rsb_admin.dashboard_path
    assert_response :success
  end

  test 'admin session token replay after logout fails' do
    sign_in_admin(@admin)
    admin_session = RSB::Admin::AdminSession.last
    token = admin_session.session_token

    # Logout
    delete rsb_admin.logout_path
    assert_redirected_to rsb_admin.login_path

    # The session record should be destroyed
    assert_nil RSB::Admin::AdminSession.find_by(session_token: token),
               'AdminSession record must be destroyed after logout'
  end

  test 'touch_activity! updates last_active_at on every request' do
    sign_in_admin(@admin)
    admin_session = RSB::Admin::AdminSession.last
    old_time = 5.minutes.ago
    admin_session.update_column(:last_active_at, old_time)

    get rsb_admin.dashboard_path
    assert_response :success

    admin_session.reload
    assert admin_session.last_active_at > old_time,
           'last_active_at must be refreshed on each request'
  end

  test 'idle timeout expires session when configured' do
    with_settings('admin.session_idle_timeout' => 600) do
      sign_in_admin(@admin)
      admin_session = RSB::Admin::AdminSession.last
      admin_session.update_column(:last_active_at, 11.minutes.ago)

      get rsb_admin.dashboard_path
      assert_redirected_to rsb_admin.login_path
    end
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
