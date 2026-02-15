# frozen_string_literal: true

require 'test_helper'

class AdminAddCredentialTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_credentials
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)

    @identity = RSB::Auth::Identity.create!(status: 'active')
    @credential = RSB::Auth::Credential::EmailPassword.create!(
      identity: @identity,
      identifier: 'existing@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )
  end

  # --- New Credential Form ---

  test 'new_credential renders the add credential form' do
    get "/admin/identities/#{@identity.id}/new_credential"
    assert_response :success
    assert_match 'Add Credential', response.body
  end

  test 'new_credential excludes types the identity already has' do
    get "/admin/identities/#{@identity.id}/new_credential"
    assert_response :success
    # Identity already has EmailPassword, so it should be excluded
    refute_match '>Email &amp; Password</a>', response.body
    # But other types should be available
    assert_match 'Username &amp; Password', response.body
  end

  test "new_credential with ?type= renders selected type's form" do
    get "/admin/identities/#{@identity.id}/new_credential?type=username_password"
    assert_response :success
    assert_match 'Username', response.body
  end

  test 'new_credential redirects if identity is not active' do
    @identity.update!(status: 'suspended')

    get "/admin/identities/#{@identity.id}/new_credential"
    assert_response :redirect
    follow_redirect!
    assert_match(/not active|non-active/i, response.body)
  end

  test 'new_credential redirects if identity is deactivated' do
    @identity.update!(status: 'deactivated')

    get "/admin/identities/#{@identity.id}/new_credential"
    assert_response :redirect
  end

  test 'new_credential shows empty state when all types are taken' do
    # Add remaining types
    RSB::Auth::Credential::PhonePassword.create!(
      identity: @identity,
      identifier: '+1234567890',
      password: 'password1234',
      password_confirmation: 'password1234'
    )
    RSB::Auth::Credential::UsernamePassword.create!(
      identity: @identity,
      identifier: 'testuser',
      password: 'password1234',
      password_confirmation: 'password1234'
    )

    get "/admin/identities/#{@identity.id}/new_credential"
    assert_response :success
    assert_match(/no credential types available/i, response.body)
  end

  # --- Add Credential ---

  test 'add_credential creates a new credential for the identity' do
    assert_difference 'RSB::Auth::Credential.count', 1 do
      post "/admin/identities/#{@identity.id}/add_credential", params: {
        credential_type: 'username_password',
        identifier: 'newusername',
        password: 'securepassword123',
        password_confirmation: 'securepassword123'
      }
    end

    assert_response :redirect
    new_cred = @identity.credentials.last
    assert_equal 'RSB::Auth::Credential::UsernamePassword', new_cred.type
    assert_equal 'newusername', new_cred.identifier
    assert new_cred.verified?
  end

  test 'add_credential redirects to show page with flash on success' do
    post "/admin/identities/#{@identity.id}/add_credential", params: {
      credential_type: 'username_password',
      identifier: 'addeduser',
      password: 'securepassword123',
      password_confirmation: 'securepassword123'
    }

    assert_redirected_to "/admin/identities/#{@identity.id}"
    follow_redirect!
    assert_match(/added/i, response.body)
  end

  test 'add_credential re-renders form on validation failure' do
    assert_no_difference 'RSB::Auth::Credential.count' do
      post "/admin/identities/#{@identity.id}/add_credential", params: {
        credential_type: 'email_password',
        identifier: 'existing@example.com', # duplicate
        password: 'securepassword123',
        password_confirmation: 'securepassword123'
      }
    end

    assert_response :unprocessable_entity
  end

  test 'add_credential rejects if identity is not active' do
    @identity.update!(status: 'suspended')

    assert_no_difference 'RSB::Auth::Credential.count' do
      post "/admin/identities/#{@identity.id}/add_credential", params: {
        credential_type: 'username_password',
        identifier: 'blocked',
        password: 'securepassword123',
        password_confirmation: 'securepassword123'
      }
    end

    assert_response :redirect
  end

  # --- Show Page Button ---

  test 'show page displays Add Credential button for active identity' do
    get "/admin/identities/#{@identity.id}"
    assert_response :success
    assert_match 'Add Credential', response.body
  end

  test 'show page hides Add Credential button for suspended identity' do
    @identity.update!(status: 'suspended')

    get "/admin/identities/#{@identity.id}"
    assert_response :success
    refute_match 'Add Credential', response.body
  end

  test 'show page hides Add Credential button for admin without permission' do
    restricted = create_test_admin!(permissions: { 'identities' => %w[index show] })
    sign_in_admin(restricted)

    get "/admin/identities/#{@identity.id}"
    assert_response :success
    refute_match 'Add Credential', response.body
  end

  # --- RBAC ---

  test 'new_credential is forbidden for admin without new_credential permission' do
    restricted = create_test_admin!(permissions: { 'identities' => %w[index show] })
    sign_in_admin(restricted)

    get "/admin/identities/#{@identity.id}/new_credential"
    assert_includes [302, 403], response.status
  end

  test 'add_credential is forbidden for admin without add_credential permission' do
    restricted = create_test_admin!(permissions: { 'identities' => %w[index show] })
    sign_in_admin(restricted)

    post "/admin/identities/#{@identity.id}/add_credential", params: {
      credential_type: 'username_password',
      identifier: 'blocked',
      password: 'securepassword123',
      password_confirmation: 'securepassword123'
    }
    assert_includes [302, 403], response.status
  end
end
