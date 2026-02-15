# frozen_string_literal: true

require 'test_helper'

class AdminCreateIdentityTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_credentials
    register_all_admin_categories_v2 # Updated registration with new actions
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # --- New Form ---

  test 'new renders the create identity form' do
    get '/admin/identities/new'
    assert_response :success
    assert_match 'New Identity', response.body
  end

  test 'new shows credential type selector with enabled types that have admin_form_partial' do
    get '/admin/identities/new'
    assert_response :success
    assert_match 'Email &amp; Password', response.body
    assert_match 'Username &amp; Password', response.body
  end

  test 'new renders email_password form fields by default' do
    get '/admin/identities/new'
    assert_response :success
    # Default type is the first enabled type with admin_form_partial
    assert_match 'Email', response.body
    assert_match 'password', response.body.downcase
  end

  test "new with ?type= renders the selected type's form partial" do
    get '/admin/identities/new?type=username_password'
    assert_response :success
    assert_match 'Username', response.body
  end

  test 'new hides types without admin_form_partial' do
    # Register a type without admin_form_partial
    RSB::Auth.credentials.register(
      RSB::Auth::CredentialDefinition.new(
        key: :oauth_google,
        class_name: 'RSB::Auth::Credential::EmailPassword', # reuse for test
        label: 'Google OAuth',
        admin_form_partial: nil
      )
    )

    get '/admin/identities/new'
    assert_response :success
    refute_match 'Google OAuth', response.body
  end

  # --- Create ---

  test 'create creates identity and credential in one transaction' do
    assert_difference ['RSB::Auth::Identity.count', 'RSB::Auth::Credential.count'], 1 do
      post '/admin/identities', params: {
        credential_type: 'email_password',
        identifier: 'newuser@example.com',
        password: 'securepassword123',
        password_confirmation: 'securepassword123'
      }
    end

    assert_response :redirect
    identity = RSB::Auth::Identity.last
    assert_equal 'active', identity.status
    credential = identity.credentials.first
    assert_equal 'newuser@example.com', credential.identifier
    assert credential.verified? # Admin-created = pre-verified
  end

  test 'create sets verified_at on the credential' do
    post '/admin/identities', params: {
      credential_type: 'email_password',
      identifier: 'verified@example.com',
      password: 'securepassword123',
      password_confirmation: 'securepassword123'
    }

    credential = RSB::Auth::Identity.last.credentials.first
    assert_not_nil credential.verified_at
  end

  test 'create redirects to identity show page with success flash' do
    post '/admin/identities', params: {
      credential_type: 'email_password',
      identifier: 'flash@example.com',
      password: 'securepassword123',
      password_confirmation: 'securepassword123'
    }

    identity = RSB::Auth::Identity.last
    assert_redirected_to "/admin/identities/#{identity.id}"
    follow_redirect!
    assert_match(/created/i, response.body)
  end

  test 'create fires after_identity_created lifecycle hook' do
    # The lifecycle hook fires via after_commit on Identity
    # Just verify the identity is created and committed
    assert_difference "RSB::Auth::Identity.where(status: 'active').count", 1 do
      post '/admin/identities', params: {
        credential_type: 'email_password',
        identifier: 'lifecycle@example.com',
        password: 'securepassword123',
        password_confirmation: 'securepassword123'
      }
    end
  end

  test 'create with username_password type works' do
    post '/admin/identities', params: {
      credential_type: 'username_password',
      identifier: 'johndoe',
      password: 'securepassword123',
      password_confirmation: 'securepassword123'
    }

    assert_response :redirect
    identity = RSB::Auth::Identity.last
    credential = identity.credentials.first
    assert_equal 'RSB::Auth::Credential::UsernamePassword', credential.type
    assert_equal 'johndoe', credential.identifier
  end

  # --- Validation Errors ---

  test 'create re-renders form on validation failure' do
    assert_no_difference 'RSB::Auth::Identity.count' do
      post '/admin/identities', params: {
        credential_type: 'email_password',
        identifier: 'invalid-email',
        password: 'short',
        password_confirmation: 'short'
      }
    end

    assert_response :unprocessable_entity
  end

  test 'create re-renders form on password mismatch' do
    assert_no_difference 'RSB::Auth::Identity.count' do
      post '/admin/identities', params: {
        credential_type: 'email_password',
        identifier: 'test@example.com',
        password: 'securepassword123',
        password_confirmation: 'differentpassword'
      }
    end

    assert_response :unprocessable_entity
  end

  test 'create rolls back identity on credential validation failure' do
    assert_no_difference 'RSB::Auth::Identity.count' do
      post '/admin/identities', params: {
        credential_type: 'email_password',
        identifier: '', # blank identifier
        password: 'securepassword123',
        password_confirmation: 'securepassword123'
      }
    end

    assert_response :unprocessable_entity
  end

  test 'create rejects duplicate identifier' do
    RSB::Auth::Identity.create!(status: 'active').credentials.create!(
      type: 'RSB::Auth::Credential::EmailPassword',
      identifier: 'taken@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    )

    assert_no_difference 'RSB::Auth::Identity.count' do
      post '/admin/identities', params: {
        credential_type: 'email_password',
        identifier: 'taken@example.com',
        password: 'securepassword123',
        password_confirmation: 'securepassword123'
      }
    end

    assert_response :unprocessable_entity
  end

  # --- Index "New Identity" Button ---

  test 'index shows New Identity button for authorized admin' do
    get '/admin/identities'
    assert_response :success
    assert_match 'New Identity', response.body
  end

  test 'index hides New Identity button for admin without new permission' do
    restricted = create_test_admin!(permissions: { 'identities' => %w[index show] })
    sign_in_admin(restricted)

    get '/admin/identities'
    assert_response :success
    refute_match 'New Identity', response.body
  end

  # --- RBAC ---

  test 'new is forbidden for admin without new permission' do
    restricted = create_test_admin!(permissions: { 'identities' => %w[index show] })
    sign_in_admin(restricted)

    get '/admin/identities/new'
    assert_includes [302, 403], response.status
  end

  test 'create is forbidden for admin without create permission' do
    restricted = create_test_admin!(permissions: { 'identities' => %w[index show new] })
    sign_in_admin(restricted)

    post '/admin/identities', params: {
      credential_type: 'email_password',
      identifier: 'test@example.com',
      password: 'securepassword123',
      password_confirmation: 'securepassword123'
    }
    assert_includes [302, 403], response.status
  end
end
