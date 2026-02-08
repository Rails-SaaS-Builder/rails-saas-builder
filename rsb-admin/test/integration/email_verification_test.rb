require "test_helper"

class EmailVerificationTest < ActionDispatch::IntegrationTest
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

  # ── Email change triggers verification ─────────────

  test "changing email stores pending_email and sends verification" do
    new_email = "new-#{SecureRandom.hex(4)}@example.com"

    assert_enqueued_emails 1 do
      patch rsb_admin.profile_path, params: {
        admin_user: { email: new_email },
        current_password: "password123"
      }
    end

    assert_redirected_to rsb_admin.profile_path
    @admin.reload
    # Original email unchanged
    refute_equal new_email, @admin.email
    # Pending email set
    assert_equal new_email, @admin.pending_email
    assert_not_nil @admin.email_verification_token
  end

  test "submitting same email does not trigger verification" do
    assert_no_enqueued_emails do
      patch rsb_admin.profile_path, params: {
        admin_user: { email: @admin.email },
        current_password: "password123"
      }
    end
    assert_redirected_to rsb_admin.profile_path
  end

  test "password-only change does not trigger verification" do
    assert_no_enqueued_emails do
      patch rsb_admin.profile_path, params: {
        admin_user: { email: @admin.email, password: "newpassword123", password_confirmation: "newpassword123" },
        current_password: "password123"
      }
    end
    assert_redirected_to rsb_admin.profile_path
    @admin.reload
    assert @admin.authenticate("newpassword123")
  end

  # ── Verify email link ──────────────────────────────

  test "verify_email with valid token updates email" do
    @admin.generate_email_verification!("verified@example.com")
    token = @admin.email_verification_token

    get rsb_admin.verify_email_profile_path(token: token)
    assert_redirected_to rsb_admin.profile_path

    @admin.reload
    assert_equal "verified@example.com", @admin.email
    assert_nil @admin.pending_email
  end

  test "verify_email with invalid token shows error" do
    delete rsb_admin.logout_path
    get rsb_admin.verify_email_profile_path(token: "invalid-token")
    assert_redirected_to rsb_admin.login_path
    follow_redirect!
    assert_match I18n.t("rsb.admin.profile.verification_invalid"), response.body
  end

  test "verify_email with expired token shows error" do
    @admin.generate_email_verification!("expired@example.com")
    token = @admin.email_verification_token

    travel RSB::Admin.configuration.email_verification_expiry + 1.minute do
      get rsb_admin.verify_email_profile_path(token: token)
      assert_redirected_to rsb_admin.profile_path
      follow_redirect!
      assert_match I18n.t("rsb.admin.profile.verification_expired"), response.body
    end
  end

  test "verify_email does not require authentication" do
    delete rsb_admin.logout_path
    @admin.generate_email_verification!("noauth@example.com")
    token = @admin.email_verification_token

    get rsb_admin.verify_email_profile_path(token: token)
    # Should not redirect to login — verify_email skips auth
    assert_redirected_to rsb_admin.profile_path
  end

  # ── Resend verification ────────────────────────────

  test "resend_verification regenerates token and sends email" do
    @admin.generate_email_verification!("resend@example.com")
    old_token = @admin.email_verification_token

    assert_enqueued_emails 1 do
      post rsb_admin.resend_verification_profile_path
    end

    @admin.reload
    refute_equal old_token, @admin.email_verification_token
    assert_redirected_to rsb_admin.profile_path
  end

  test "resend_verification does nothing when no pending email" do
    assert_no_enqueued_emails do
      post rsb_admin.resend_verification_profile_path
    end
    assert_redirected_to rsb_admin.profile_path
  end

  # ── Profile show displays pending email ────────────

  test "profile show displays pending email notice" do
    @admin.generate_email_verification!("pending@example.com")

    get rsb_admin.profile_path
    assert_response :success
    assert_match "pending@example.com", response.body
    assert_match I18n.t("rsb.admin.profile.pending_email"), response.body
  end

  # ── Password change revokes other sessions ─────────

  test "password change destroys other sessions" do
    # Create another session for the same user
    RSB::Admin::AdminSession.create!(
      admin_user: @admin,
      session_token: "other-session-token",
      last_active_at: Time.current
    )
    assert @admin.admin_sessions.count >= 2

    patch rsb_admin.profile_path, params: {
      admin_user: { email: @admin.email, password: "newpassword123", password_confirmation: "newpassword123" },
      current_password: "password123"
    }

    # Only the current session should remain
    assert_equal 1, @admin.admin_sessions.count
  end

  # ── Pending email uniqueness ───────────────────────

  test "cannot set pending email that is already taken" do
    other = RSB::Admin::AdminUser.create!(
      email: "other-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: @role
    )

    patch rsb_admin.profile_path, params: {
      admin_user: { email: other.email },
      current_password: "password123"
    }
    assert_response :unprocessable_entity
  end
end
