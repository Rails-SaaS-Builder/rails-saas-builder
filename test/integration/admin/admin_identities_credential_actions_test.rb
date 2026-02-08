require "test_helper"

class AdminIdentitiesCredentialActionsTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    @identity = RSB::Auth::Identity.create!(status: "active")
    @credential = RSB::Auth::Credential::EmailPassword.create!(
      identity: @identity,
      identifier: "test@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )
  end

  # --- Revoke ---

  test "revoke_credential sets revoked_at on active credential" do
    patch "/admin/identities/#{@identity.id}/revoke_credential",
          params: { credential_id: @credential.id }

    assert_response :redirect
    @credential.reload
    assert @credential.revoked?
  end

  test "revoke_credential redirects with notice on success" do
    patch "/admin/identities/#{@identity.id}/revoke_credential",
          params: { credential_id: @credential.id }

    assert_redirected_to "/admin/identities/#{@identity.id}"
    follow_redirect!
    assert_match I18n.t("rsb.auth.credentials.revoked_notice"), flash[:notice]
  end

  test "revoke_credential shows alert when already revoked" do
    @credential.update_columns(revoked_at: Time.current)

    patch "/admin/identities/#{@identity.id}/revoke_credential",
          params: { credential_id: @credential.id }

    assert_redirected_to "/admin/identities/#{@identity.id}"
    follow_redirect!
    assert_match "already revoked", flash[:alert]
  end

  # --- Restore ---

  test "restore_credential clears revoked_at on revoked credential" do
    @credential.update_columns(revoked_at: Time.current)

    patch "/admin/identities/#{@identity.id}/restore_credential",
          params: { credential_id: @credential.id }

    assert_response :redirect
    @credential.reload
    assert_not @credential.revoked?
  end

  test "restore_credential redirects with notice on success" do
    @credential.update_columns(revoked_at: Time.current)

    patch "/admin/identities/#{@identity.id}/restore_credential",
          params: { credential_id: @credential.id }

    assert_redirected_to "/admin/identities/#{@identity.id}"
    follow_redirect!
    assert_match I18n.t("rsb.auth.credentials.restored_notice"), flash[:notice]
  end

  test "restore_credential shows alert when conflict exists" do
    @credential.update_columns(revoked_at: Time.current)

    # Create a new active credential with same identifier
    other_identity = RSB::Auth::Identity.create!
    other_identity.credentials.create!(
      type: "RSB::Auth::Credential::EmailPassword",
      identifier: "test@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    )

    patch "/admin/identities/#{@identity.id}/restore_credential",
          params: { credential_id: @credential.id }

    assert_redirected_to "/admin/identities/#{@identity.id}"
    follow_redirect!
    assert_match I18n.t("rsb.auth.credentials.restore_conflict"), flash[:alert]
    assert @credential.reload.revoked?  # still revoked
  end

  # --- Show page ---

  test "show page displays status column for credentials" do
    get "/admin/identities/#{@identity.id}"
    assert_response :success
    assert_select "th", text: "Status"
    assert_select "span", text: I18n.t("rsb.auth.credentials.active")
  end

  test "show page displays Revoke button for active credential" do
    get "/admin/identities/#{@identity.id}"
    assert_response :success
    # button_to may render <input type="submit"> or <button> depending on Rails version
    assert (response.body.include?("Revoke") && response.body.include?("revoke_credential")),
      "Expected page to show Revoke button for credential"
  end

  test "show page displays Restore button for revoked credential" do
    @credential.update_columns(revoked_at: Time.current)

    get "/admin/identities/#{@identity.id}"
    assert_response :success
    assert (response.body.include?("Restore") && response.body.include?("restore_credential")),
      "Expected page to show Restore button for credential"
  end

  test "show page displays revoked badge for revoked credential" do
    @credential.update_columns(revoked_at: Time.current)

    get "/admin/identities/#{@identity.id}"
    assert_response :success
    assert_select "span", text: I18n.t("rsb.auth.credentials.revoked")
  end

  # --- RBAC ---

  test "admin with identity permissions can revoke and restore credentials" do
    permitted = create_test_admin!(permissions: {
      "identities" => ["index", "show", "revoke_credential", "restore_credential"]
    })
    sign_in_admin(permitted)

    patch "/admin/identities/#{@identity.id}/revoke_credential",
          params: { credential_id: @credential.id }
    assert_redirected_to "/admin/identities/#{@identity.id}"
    assert @credential.reload.revoked?

    patch "/admin/identities/#{@identity.id}/restore_credential",
          params: { credential_id: @credential.id }
    assert_redirected_to "/admin/identities/#{@identity.id}"
    assert_not @credential.reload.revoked?
  end

  test "restricted admin cannot revoke credential" do
    restricted = create_test_admin!(permissions: { "other" => ["index"] })
    sign_in_admin(restricted)

    patch "/admin/identities/#{@identity.id}/revoke_credential",
          params: { credential_id: @credential.id }
    assert_includes [302, 403], response.status
    assert_not @credential.reload.revoked?
  end

  private

  def default_url_options
    { host: "localhost" }
  end
end
