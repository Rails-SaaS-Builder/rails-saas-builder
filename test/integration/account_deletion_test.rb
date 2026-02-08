require "test_helper"

class AccountDeletionIntegrationTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_admin_categories
    register_all_credentials
    Rails.cache.clear
  end

  # --- Setting Registration ---

  test "account_deletion_enabled setting is registered and resolvable" do
    value = RSB::Settings.get("auth.account_deletion_enabled")
    assert_equal true, value
  end

  test "account_deletion_enabled setting can be overridden" do
    with_settings("auth.account_deletion_enabled" => false) do
      assert_equal false, RSB::Settings.get("auth.account_deletion_enabled")
    end
  end

  # --- Admin Registration ---

  test "admin identity registration includes restore action" do
    registration = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
    assert_not_nil registration, "Identity should be registered in admin registry"
    assert_includes registration.actions, :restore
  end

  test "admin identity registration includes all expected actions" do
    registration = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
    expected = [:index, :show, :suspend, :activate, :deactivate, :revoke_credential, :restore_credential, :restore]
    expected.each do |action|
      assert_includes registration.actions, action, "Expected #{action} in identity registration actions"
    end
  end

  test "admin identity status filter includes deleted" do
    registration = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
    status_filter = registration.filters.find { |f| f.key == :status }
    assert_not_nil status_filter, "Status filter should exist"
    assert_includes status_filter.options, "deleted"
  end

  test "admin identity status filter includes all four statuses" do
    registration = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
    status_filter = registration.filters.find { |f| f.key == :status }
    %w[active suspended deactivated deleted].each do |status|
      assert_includes status_filter.options, status
    end
  end

  # --- Full Deletion Flow ---

  test "full deletion flow: login, delete, cannot login" do
    identity = create_test_identity
    credential = create_test_credential(
      identity: identity,
      email: "deleteme@example.com",
      password: "password1234"
    )

    # Sign in via HTTP
    login_as("deleteme@example.com")

    # Visit account page
    get "/auth/account"
    assert_response :success

    # Visit confirm destroy page
    get "/auth/account/confirm_destroy"
    assert_response :success

    # Delete account with correct password
    delete "/auth/account", params: { password: "password1234" }
    assert_redirected_to "/auth/session/new"

    # Verify identity is deleted
    identity.reload
    assert identity.deleted?
    assert_not_nil identity.deleted_at

    # Verify all credentials are revoked
    credential.reload
    assert credential.revoked?

    # Verify cannot authenticate
    result = RSB::Auth::AuthenticationService.new.call(
      identifier: "deleteme@example.com",
      password: "password1234"
    )
    assert_not result.success?
  end

  test "deletion with wrong password fails" do
    identity = create_test_identity
    create_test_credential(
      identity: identity,
      email: "wrongpw@example.com",
      password: "password1234"
    )

    login_as("wrongpw@example.com")

    delete "/auth/account", params: { password: "wrongpassword" }
    # Should not redirect to login — should re-render confirm_destroy
    identity.reload
    assert identity.active?, "Identity should still be active after wrong password"
  end

  test "deletion disabled setting prevents account deletion" do
    identity = create_test_identity
    create_test_credential(identity: identity, email: "nodeletion@example.com", password: "password1234")
    login_as("nodeletion@example.com")

    with_settings("auth.account_deletion_enabled" => false) do
      get "/auth/account"
      assert_response :success

      delete "/auth/account", params: { password: "password1234" }
      # Should redirect with alert, not actually delete
      identity.reload
      assert identity.active?, "Identity should still be active when deletion is disabled"
    end
  end

  # --- Admin Restore Flow ---

  test "admin can restore a deleted identity" do
    identity = create_test_identity(status: :deleted)
    identity.update_columns(deleted_at: 1.day.ago)
    credential = create_test_credential(identity: identity, email: "restore@example.com")
    credential.update_columns(revoked_at: 1.day.ago)

    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    patch "/admin/identities/#{identity.id}/restore"
    assert_response :redirect

    identity.reload
    assert identity.active?
    assert_nil identity.deleted_at

    # Credential should remain revoked
    credential.reload
    assert credential.revoked?, "Credential should remain revoked after identity restore"
  end

  test "admin restore then manual credential restore allows login" do
    identity = create_test_identity(status: :deleted)
    identity.update_columns(deleted_at: 1.day.ago)
    credential = create_test_credential(identity: identity, email: "fullrestore@example.com")
    credential.update_columns(revoked_at: 1.day.ago)

    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    # Step 1: Restore identity
    patch "/admin/identities/#{identity.id}/restore"
    assert_response :redirect

    # Step 2: Restore credential
    patch "/admin/identities/#{identity.id}/restore_credential",
          params: { credential_id: credential.id }
    assert_response :redirect

    # Step 3: Verify user can now authenticate
    result = RSB::Auth::AuthenticationService.new.call(
      identifier: "fullrestore@example.com",
      password: "password1234"
    )
    assert result.success?
  end

  # --- Lifecycle Hooks in Integrated Environment ---

  test "lifecycle hooks fire for deletion and restoration" do
    deleted_identities = []
    restored_identities = []

    handler_class = Class.new(RSB::Auth::LifecycleHandler) do
      define_method(:after_identity_deleted) { |identity| deleted_identities << identity }
      define_method(:after_identity_restored) { |identity| restored_identities << identity }
    end

    RSB::Auth.const_set(:TestDeletionFlowHandler, handler_class)
    RSB::Auth.configuration.lifecycle_handler = "RSB::Auth::TestDeletionFlowHandler"

    identity = create_test_identity
    create_test_credential(identity: identity, email: "lifecycle@example.com", password: "password1234")

    # Delete via user flow
    login_as("lifecycle@example.com")
    delete "/auth/account", params: { password: "password1234" }

    assert_equal [identity], deleted_identities
    assert_empty restored_identities

    # Restore via admin flow
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)
    patch "/admin/identities/#{identity.id}/restore"

    assert_equal [identity], restored_identities
  ensure
    RSB::Auth.configuration.lifecycle_handler = nil
    RSB::Auth.send(:remove_const, :TestDeletionFlowHandler) if RSB::Auth.const_defined?(:TestDeletionFlowHandler)
  end

  # --- Regression: Existing Flows Still Work ---

  test "credential revoke and restore still works after TDD-002 changes" do
    identity = create_test_identity
    credential = create_test_credential(identity: identity, email: "revoke@example.com")

    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    # Revoke credential
    patch "/admin/identities/#{identity.id}/revoke_credential",
          params: { credential_id: credential.id }
    assert_response :redirect
    assert credential.reload.revoked?

    # Restore credential
    patch "/admin/identities/#{identity.id}/restore_credential",
          params: { credential_id: credential.id }
    assert_response :redirect
    assert_not credential.reload.revoked?
  end

  test "admin identity index still works with deleted filter" do
    create_test_identity(status: :active)
    deleted = create_test_identity(status: :deleted)
    deleted.update_columns(deleted_at: 1.day.ago)

    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get "/admin/identities", params: { q: { status: "deleted" } }
    assert_response :success
  end

  test "admin sessions management page still works" do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    get "/admin/sessions_management"
    assert_response :success
  end

  private

  def login_as(email, password: "password1234")
    post "/auth/session", params: { identifier: email, password: password }
  end

  def default_url_options
    { host: "localhost" }
  end
end
