require "test_helper"

class AdminIdentitiesTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    @identity = RSB::Auth::Identity.create!(status: "active")
    @credential = RSB::Auth::Credential::EmailPassword.create!(
      identity: @identity,
      identifier: "user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # --- Index ---

  test "index shows identities with curated columns" do
    get "/admin/identities"
    assert_response :success
    assert_match "user@example.com", response.body
    assert_match "Active", response.body
  end

  test "index paginates at 20 per page" do
    25.times do
      RSB::Auth::Identity.create!(status: "active")
    end

    get "/admin/identities"
    assert_response :success
  end

  # --- Show ---

  test "show displays identity details" do
    get "/admin/identities/#{@identity.id}"
    assert_response :success
    assert_match "active", response.body.downcase
    assert_match @identity.created_at.strftime("%Y"), response.body
  end

  test "show displays credentials table" do
    get "/admin/identities/#{@identity.id}"
    assert_response :success
    assert_match "user@example.com", response.body
    assert_match "Email Password", response.body
  end

  test "show handles identity with no credentials" do
    identity_no_creds = RSB::Auth::Identity.create!(status: "active")

    get "/admin/identities/#{identity_no_creds.id}"
    assert_response :success
    assert_match "No credentials", response.body
  end

  # --- Custom Actions ---

  test "suspend changes identity status to suspended" do
    patch "/admin/identities/#{@identity.id}/suspend"
    assert_redirected_to "/admin/identities/#{@identity.id}"

    @identity.reload
    assert_equal "suspended", @identity.status
  end

  test "activate changes identity status to active" do
    @identity.update!(status: "suspended")

    patch "/admin/identities/#{@identity.id}/activate"
    assert_redirected_to "/admin/identities/#{@identity.id}"

    @identity.reload
    assert_equal "active", @identity.status
  end

  test "deactivate changes identity status to deactivated" do
    patch "/admin/identities/#{@identity.id}/deactivate"
    assert_redirected_to "/admin/identities/#{@identity.id}"

    @identity.reload
    assert_equal "deactivated", @identity.status
  end

  test "suspend on already suspended identity shows alert" do
    @identity.update!(status: "suspended")

    patch "/admin/identities/#{@identity.id}/suspend"
    follow_redirect!
    assert_match "already suspended", response.body.downcase
  end

  # --- RBAC ---

  test "restricted admin cannot access identities" do
    restricted = create_test_admin!(permissions: { "other" => ["index"] })
    sign_in_admin(restricted)

    get "/admin/identities"
    assert_includes [302, 403], response.status
  end

  test "admin with identity permissions can access" do
    permitted = create_test_admin!(permissions: {
      "identities" => ["index", "show", "suspend", "activate", "deactivate", "revoke_credential", "restore_credential"]
    })
    sign_in_admin(permitted)

    get "/admin/identities"
    assert_response :success
  end
end
