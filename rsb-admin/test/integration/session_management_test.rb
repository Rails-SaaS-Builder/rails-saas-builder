require "test_helper"

class SessionManagementTest < ActionDispatch::IntegrationTest
  setup do
    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { "*" => ["*"] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: @role
    )
    post rsb_admin.login_path, params: { email: @admin.email, password: "password123" }
  end

  # ── Profile shows sessions ─────────────────────────

  test "profile page lists active sessions" do
    get rsb_admin.profile_path
    assert_response :success
    assert_match I18n.t("rsb.admin.profile.sessions_title"), response.body
    assert_match I18n.t("rsb.admin.profile.current_session"), response.body
  end

  test "current session shows Current badge" do
    get rsb_admin.profile_path
    assert_response :success
    assert_match I18n.t("rsb.admin.profile.current_session"), response.body
  end

  test "current session does not show Revoke button" do
    get rsb_admin.profile_path
    assert_response :success
    # Current session should not have a revoke form targeting it
    current = @admin.admin_sessions.last
    refute_match "profile/sessions/#{current.id}", response.body
  end

  # ── Revoke single session ──────────────────────────

  test "revoke a non-current session" do
    other_session = RSB::Admin::AdminSession.create!(
      admin_user: @admin,
      session_token: "other-token-#{SecureRandom.hex(4)}",
      ip_address: "10.0.0.1",
      browser: "Firefox",
      os: "Linux",
      device_type: "desktop",
      last_active_at: 1.hour.ago
    )

    assert_difference "RSB::Admin::AdminSession.count", -1 do
      delete rsb_admin.profile_session_path(other_session)
    end

    assert_redirected_to rsb_admin.profile_path
    follow_redirect!
    assert_match I18n.t("rsb.admin.profile.session_revoked"), response.body
  end

  test "cannot revoke current session" do
    current = @admin.admin_sessions.last

    assert_no_difference "RSB::Admin::AdminSession.count" do
      delete rsb_admin.profile_session_path(current)
    end

    assert_redirected_to rsb_admin.profile_path
    follow_redirect!
    assert_match I18n.t("rsb.admin.profile.cannot_revoke_current"), response.body
  end

  test "cannot revoke another user's session" do
    other_admin = RSB::Admin::AdminUser.create!(
      email: "other-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: @role
    )
    other_session = RSB::Admin::AdminSession.create!(
      admin_user: other_admin,
      session_token: "other-user-token-#{SecureRandom.hex(4)}",
      last_active_at: Time.current
    )

    assert_no_difference "RSB::Admin::AdminSession.count" do
      delete rsb_admin.profile_session_path(other_session)
    end

    assert_redirected_to rsb_admin.profile_path
    follow_redirect!
    assert_match I18n.t("rsb.admin.profile.session_not_found"), response.body
  end

  # ── Revoke all other sessions ──────────────────────

  test "revoke all other sessions" do
    # Create 2 additional sessions
    2.times do
      RSB::Admin::AdminSession.create!(
        admin_user: @admin,
        session_token: SecureRandom.urlsafe_base64(32),
        last_active_at: Time.current
      )
    end

    assert_equal 3, @admin.admin_sessions.count

    delete rsb_admin.profile_sessions_path

    assert_equal 1, @admin.admin_sessions.count  # only current remains
    assert_redirected_to rsb_admin.profile_path
    follow_redirect!
    assert_match "2 sessions revoked", response.body
  end

  test "revoke all when only current session exists" do
    assert_equal 1, @admin.admin_sessions.count

    delete rsb_admin.profile_sessions_path

    assert_equal 1, @admin.admin_sessions.count  # current session untouched
    assert_redirected_to rsb_admin.profile_path
  end

  # ── Multiple sessions display ──────────────────────

  test "multiple sessions shown with device info" do
    RSB::Admin::AdminSession.create!(
      admin_user: @admin,
      session_token: SecureRandom.urlsafe_base64(32),
      ip_address: "10.0.0.1",
      browser: "Firefox",
      os: "Linux",
      device_type: "desktop",
      last_active_at: 30.minutes.ago
    )

    get rsb_admin.profile_path
    assert_response :success
    assert_match "Firefox", response.body
    assert_match "Linux", response.body
    assert_match "10.0.0.1", response.body
  end

  # ── No RBAC required ───────────────────────────────

  test "admin with no role can manage sessions" do
    no_role_admin = RSB::Admin::AdminUser.create!(
      email: "norole-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: nil
    )
    delete rsb_admin.logout_path
    post rsb_admin.login_path, params: { email: no_role_admin.email, password: "password123" }

    get rsb_admin.profile_path
    assert_response :success
    assert_match I18n.t("rsb.admin.profile.sessions_title"), response.body
  end
end
