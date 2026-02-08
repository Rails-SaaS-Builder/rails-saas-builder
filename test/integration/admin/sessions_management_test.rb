require "test_helper"

class AdminSessionsManagementTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # --- Index ---

  test "index shows active sessions" do
    identity = RSB::Auth::Identity.create!(status: "active")
    RSB::Auth::Session.create!(
      identity: identity,
      ip_address: "127.0.0.1",
      user_agent: "Mozilla/5.0"
    )

    get "/admin/sessions_management"
    assert_response :success
    assert_match "127.0.0.1", response.body
  end

  test "index does not show expired sessions" do
    identity = RSB::Auth::Identity.create!(status: "active")
    expired_session = RSB::Auth::Session.create!(
      identity: identity,
      ip_address: "10.0.0.1",
      user_agent: "Expired Agent"
    )
    # Use update_column to bypass callbacks that would reset expires_at
    expired_session.update_column(:expires_at, 1.hour.ago)

    get "/admin/sessions_management"
    assert_response :success
    refute_match "10.0.0.1", response.body
  end

  test "index paginates sessions at 20 per page" do
    identity = RSB::Auth::Identity.create!(status: "active")
    25.times do |i|
      RSB::Auth::Session.create!(
        identity: identity,
        ip_address: "192.168.1.#{i}",
        user_agent: "Agent #{i}"
      )
    end

    get "/admin/sessions_management"
    assert_response :success
    # Should show first 20, not all 25
    # The response should contain pagination controls
    assert_match "Next", response.body
  end

  # --- Destroy (Revoke) ---

  test "destroy revokes a session" do
    identity = RSB::Auth::Identity.create!(status: "active")
    session_record = RSB::Auth::Session.create!(
      identity: identity,
      ip_address: "127.0.0.1",
      user_agent: "Mozilla/5.0"
    )

    assert_not session_record.expired?

    delete "/admin/sessions_management/#{session_record.id}"
    assert_redirected_to "/admin/sessions_management"

    session_record.reload
    assert session_record.expired?, "Session should be expired after revocation"
  end

  test "destroy shows success flash message" do
    identity = RSB::Auth::Identity.create!(status: "active")
    session_record = RSB::Auth::Session.create!(
      identity: identity,
      ip_address: "127.0.0.1",
      user_agent: "Mozilla/5.0"
    )

    delete "/admin/sessions_management/#{session_record.id}"
    follow_redirect!
    assert_match "Session revoked", response.body
  end

  # --- RBAC ---

  test "restricted admin cannot access sessions management" do
    restricted = create_test_admin!(permissions: { "other" => ["index"] })
    sign_in_admin(restricted)

    get "/admin/sessions_management"
    assert_includes [302, 403], response.status
  end

  test "admin with sessions_management permission can access" do
    permitted = create_test_admin!(permissions: { "sessions_management" => ["index", "destroy"] })
    sign_in_admin(permitted)

    get "/admin/sessions_management"
    assert_response :success
  end
end
