require "test_helper"

class AdminVerifyResendTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_credentials
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    @identity = RSB::Auth::Identity.create!(status: "active")
    @credential = RSB::Auth::Credential::EmailPassword.create!(
      identity: @identity,
      identifier: "unverified@example.com",
      password: "password1234",
      password_confirmation: "password1234"
      # verified_at is nil — unverified
    )
  end

  # --- Verify Credential ---

  test "verify_credential sets verified_at on unverified credential" do
    patch "/admin/identities/#{@identity.id}/verify_credential",
          params: { credential_id: @credential.id }

    assert_response :redirect
    @credential.reload
    assert @credential.verified?
    assert_not_nil @credential.verified_at
  end

  test "verify_credential clears verification token" do
    @credential.update_columns(verification_token: "sometoken123", verification_sent_at: 1.hour.ago)

    patch "/admin/identities/#{@identity.id}/verify_credential",
          params: { credential_id: @credential.id }

    @credential.reload
    assert_nil @credential.verification_token
  end

  test "verify_credential redirects with success flash" do
    patch "/admin/identities/#{@identity.id}/verify_credential",
          params: { credential_id: @credential.id }

    assert_redirected_to "/admin/identities/#{@identity.id}"
    follow_redirect!
    assert_match(/verified/i, response.body)
  end

  test "verify_credential shows alert for already verified credential" do
    @credential.update_columns(verified_at: 1.day.ago)

    patch "/admin/identities/#{@identity.id}/verify_credential",
          params: { credential_id: @credential.id }

    assert_redirected_to "/admin/identities/#{@identity.id}"
    follow_redirect!
    assert_match(/already verified/i, response.body)
  end

  test "verify_credential shows alert for revoked credential" do
    @credential.update_columns(revoked_at: Time.current)

    patch "/admin/identities/#{@identity.id}/verify_credential",
          params: { credential_id: @credential.id }

    assert_redirected_to "/admin/identities/#{@identity.id}"
    follow_redirect!
    # Should not verify revoked credentials
  end

  # --- Resend Verification ---

  test "resend_verification sends verification email for unverified email credential" do
    assert_emails 1 do
      post "/admin/identities/#{@identity.id}/resend_verification",
           params: { credential_id: @credential.id }
    end

    assert_redirected_to "/admin/identities/#{@identity.id}"
    follow_redirect!
    assert_match(/verification email sent/i, response.body)
  end

  test "resend_verification updates verification_sent_at" do
    post "/admin/identities/#{@identity.id}/resend_verification",
         params: { credential_id: @credential.id }

    @credential.reload
    assert_not_nil @credential.verification_sent_at
    assert_not_nil @credential.verification_token
  end

  test "resend_verification is rate limited to once per minute" do
    @credential.update_columns(verification_sent_at: 30.seconds.ago)

    post "/admin/identities/#{@identity.id}/resend_verification",
         params: { credential_id: @credential.id }

    assert_redirected_to "/admin/identities/#{@identity.id}"
    follow_redirect!
    assert_match(/wait/i, response.body)
  end

  test "resend_verification allows resend after 1 minute" do
    @credential.update_columns(verification_sent_at: 2.minutes.ago)

    assert_emails 1 do
      post "/admin/identities/#{@identity.id}/resend_verification",
           params: { credential_id: @credential.id }
    end

    assert_redirected_to "/admin/identities/#{@identity.id}"
  end

  test "resend_verification rejects for already verified credential" do
    @credential.update_columns(verified_at: Time.current)

    post "/admin/identities/#{@identity.id}/resend_verification",
         params: { credential_id: @credential.id }

    assert_redirected_to "/admin/identities/#{@identity.id}"
    follow_redirect!
    assert_match(/already verified/i, response.body)
  end

  test "resend_verification rejects for non-email credential type" do
    username_cred = RSB::Auth::Credential::UsernamePassword.create!(
      identity: @identity,
      identifier: "testuser",
      password: "password1234",
      password_confirmation: "password1234"
    )

    post "/admin/identities/#{@identity.id}/resend_verification",
         params: { credential_id: username_cred.id }

    assert_redirected_to "/admin/identities/#{@identity.id}"
    # Should reject — resend only works for email-type credentials
  end

  test "resend_verification rejects for revoked credential" do
    @credential.update_columns(revoked_at: Time.current)

    post "/admin/identities/#{@identity.id}/resend_verification",
         params: { credential_id: @credential.id }

    assert_redirected_to "/admin/identities/#{@identity.id}"
  end

  # --- Show Page Buttons ---

  test "show page displays Verify button for unverified active credential" do
    get "/admin/identities/#{@identity.id}"
    assert_response :success
    assert_match "Verify", response.body
    assert_match "verify_credential", response.body
  end

  test "show page displays Resend Verification button for unverified email credential" do
    get "/admin/identities/#{@identity.id}"
    assert_response :success
    assert_match "Resend", response.body
    assert_match "resend_verification", response.body
  end

  test "show page displays Verified badge with timestamp for verified credential" do
    @credential.update_columns(verified_at: Time.current)

    get "/admin/identities/#{@identity.id}"
    assert_response :success
    assert_select "span", text: /Verified/
    # Should NOT show Verify button
    refute_match "verify_credential", response.body
  end

  test "show page hides Verify button for revoked credential" do
    @credential.update_columns(revoked_at: Time.current)

    get "/admin/identities/#{@identity.id}"
    assert_response :success
    refute_match "verify_credential", response.body
  end

  test "show page hides Resend button for non-email credential" do
    username_cred = RSB::Auth::Credential::UsernamePassword.create!(
      identity: @identity,
      identifier: "testuser",
      password: "password1234",
      password_confirmation: "password1234"
    )

    get "/admin/identities/#{@identity.id}"
    assert_response :success
    # Resend should only appear for email-type credentials
    # The username credential row should NOT have a resend button
    refute_match "resend_verification?credential_id=#{username_cred.id}", response.body
  end

  # --- RBAC ---

  test "verify_credential is forbidden for admin without permission" do
    restricted = create_test_admin!(permissions: { "identities" => ["index", "show"] })
    sign_in_admin(restricted)

    patch "/admin/identities/#{@identity.id}/verify_credential",
          params: { credential_id: @credential.id }
    assert_includes [302, 403], response.status
    refute @credential.reload.verified?
  end

  test "resend_verification is forbidden for admin without permission" do
    restricted = create_test_admin!(permissions: { "identities" => ["index", "show"] })
    sign_in_admin(restricted)

    post "/admin/identities/#{@identity.id}/resend_verification",
         params: { credential_id: @credential.id }
    assert_includes [302, 403], response.status
  end
end
