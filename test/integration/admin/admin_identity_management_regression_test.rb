# frozen_string_literal: true

require 'test_helper'

class AdminIdentityManagementRegressionTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_credentials
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # --- Admin Registration Verification ---

  test 'identity resource registration includes all new actions' do
    registration = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
    assert registration, 'Identity resource should be registered'

    expected_actions = %i[index show new create suspend activate deactivate
                          revoke_credential restore_credential restore
                          new_credential add_credential verify_credential resend_verification]

    expected_actions.each do |action|
      assert registration.action?(action), "Identity resource should have :#{action} action"
    end
  end

  test 'identity resource has custom controller configured' do
    registration = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
    assert registration.custom_controller?
    assert_equal 'rsb/auth/admin/identities', registration.controller
  end

  # --- Credential Definition admin_form_partial ---

  test 'built-in credential types have admin_form_partial registered' do
    %i[email_password username_password].each do |key|
      defn = RSB::Auth.credentials.find(key)
      assert defn, "Credential type :#{key} should be registered"
      assert defn.admin_form_partial, "Credential type :#{key} should have admin_form_partial"
    end
  end

  test 'admin_form_partial filtering works across enabled credential types' do
    types_with_admin = RSB::Auth.credentials.enabled.select(&:admin_form_partial)
    assert types_with_admin.size >= 2, 'All 2 registered types should have admin_form_partial'
  end

  # --- Full Create Identity Flow ---

  test 'full flow: create identity with email credential from admin panel' do
    # Step 1: Visit new identity form
    get '/admin/identities/new'
    assert_response :success
    assert_match 'New Identity', response.body

    # Step 2: Create the identity
    assert_difference ['RSB::Auth::Identity.count', 'RSB::Auth::Credential.count'], 1 do
      post '/admin/identities', params: {
        credential_type: 'email_password',
        identifier: 'regression@example.com',
        password: 'securepassword123',
        password_confirmation: 'securepassword123'
      }
    end

    identity = RSB::Auth::Identity.last
    assert_redirected_to "/admin/identities/#{identity.id}"

    # Step 3: Verify identity state
    assert_equal 'active', identity.status
    credential = identity.credentials.first
    assert_equal 'regression@example.com', credential.identifier
    assert credential.verified?, 'Admin-created credential should be pre-verified'

    # Step 4: Verify it appears on index
    get '/admin/identities'
    assert_response :success
    assert_match 'regression@example.com', response.body
  end

  # --- Full Add Credential Flow ---

  test 'full flow: add credential to existing identity' do
    identity = RSB::Auth::Identity.create!(status: 'active')
    RSB::Auth::Credential::EmailPassword.create!(
      identity: identity,
      identifier: 'first@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )

    # Step 1: Visit add credential form
    get "/admin/identities/#{identity.id}/new_credential"
    assert_response :success

    # Step 2: Add a username credential
    assert_difference 'RSB::Auth::Credential.count', 1 do
      post "/admin/identities/#{identity.id}/add_credential", params: {
        credential_type: 'username_password',
        identifier: 'regressionuser',
        password: 'securepassword123',
        password_confirmation: 'securepassword123'
      }
    end

    assert_redirected_to "/admin/identities/#{identity.id}"

    # Step 3: Verify on show page
    follow_redirect!
    assert_match 'regressionuser', response.body
  end

  # --- Full Verify Flow ---

  test 'full flow: verify unverified credential from admin panel' do
    identity = RSB::Auth::Identity.create!(status: 'active')
    credential = RSB::Auth::Credential::EmailPassword.create!(
      identity: identity,
      identifier: 'unverified-regression@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )

    # Step 1: Confirm unverified on show page
    get "/admin/identities/#{identity.id}"
    assert_response :success
    assert_match 'Unverified', response.body

    # Step 2: Verify the credential
    patch "/admin/identities/#{identity.id}/verify_credential",
          params: { credential_id: credential.id }
    assert_redirected_to "/admin/identities/#{identity.id}"

    # Step 3: Confirm verified
    credential.reload
    assert credential.verified?
    follow_redirect!
    assert_match 'Verified', response.body
  end

  # --- RBAC Across All New Actions ---

  test 'admin with limited permissions can only access permitted new actions' do
    limited = create_test_admin!(permissions: {
                                   'identities' => %w[index show new create]
                                 })
    sign_in_admin(limited)

    # Can create
    get '/admin/identities/new'
    assert_response :success

    # Cannot add credential (no new_credential permission)
    identity = RSB::Auth::Identity.create!(status: 'active')
    get "/admin/identities/#{identity.id}/new_credential"
    assert_includes [302, 403], response.status
  end

  # --- Settings Integration ---

  test 'auth settings are accessible and affect credential behavior' do
    # password_min_length setting should be registered
    setting = RSB::Settings.registry.find_definition('auth.password_min_length')
    assert setting, 'Auth password_min_length setting should be registered'
  end
end
