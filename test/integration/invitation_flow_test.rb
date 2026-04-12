# frozen_string_literal: true

require 'test_helper'

class InvitationFlowTest < ActionDispatch::IntegrationTest
  include RSB::Auth::Engine.routes.url_helpers

  setup do
    register_all_settings
    register_all_credentials
    register_notifiers
    register_all_admin_categories
  end

  # --- Settings cross-gem ---

  test 'invitation settings are registered and resolvable' do
    assert_equal 168, RSB::Settings.get('auth.invitation_expiry_hours')
    assert_equal 1, RSB::Settings.get('auth.invitation_default_max_uses')
  end

  test 'invitation settings can be overridden via set' do
    RSB::Settings.set('auth.invitation_expiry_hours', 48)
    assert_equal 48, RSB::Settings.get('auth.invitation_expiry_hours')
  end

  # --- Admin registration ---

  test 'invitation resource is registered in admin with correct actions' do
    resource = RSB::Admin.registry.find_resource(RSB::Auth::Invitation)
    assert resource, 'Invitation resource should be registered in admin'

    expected_actions = %i[index show new create revoke deliver redeliver extend_expiry]
    expected_actions.each do |action|
      assert resource.action?(action), "Missing action: #{action}"
    end
  end

  test 'invitation resource has correct filters' do
    resource = RSB::Admin.registry.find_resource(RSB::Auth::Invitation)
    filter_keys = resource.filters.map(&:key)
    assert_includes filter_keys, :status
    assert_includes filter_keys, :label
  end

  # --- Full form registration flow with invite token ---

  test 'full form registration with invite token in invite_only mode' do
    RSB::Settings.set('auth.registration_mode', 'invite_only')
    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now, max_uses: 1)

    # Step 1: Visit invite link — should redirect to registration
    get "/auth/invitations/#{invitation.token}"
    assert_redirected_to new_registration_path(invite_token: invitation.token)

    # Step 2: Follow redirect — registration page should render
    follow_redirect!
    assert_response :success

    # Step 3: Submit registration form
    post '/auth/registration', params: {
      identifier: 'invited@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      invite_token: invitation.token
    }
    assert_response :redirect

    # Step 4: Verify invitation was used
    invitation.reload
    assert_equal 1, invitation.uses_count

    # Step 5: Verify identity was created with invitation tracking
    identity = RSB::Auth::Identity.last
    assert_equal invitation.id, identity.metadata['invitation_id']

    # Step 6: Verify registered_identities query works
    assert_includes invitation.registered_identities, identity
  end

  test 'form registration without token in invite_only mode is blocked' do
    RSB::Settings.set('auth.registration_mode', 'invite_only')

    post '/auth/registration', params: {
      identifier: 'blocked@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    }

    assert_response :unprocessable_entity
  end

  test 'form registration in open mode with invite token tracks it' do
    RSB::Settings.set('auth.registration_mode', 'open')
    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now, max_uses: 5)

    post '/auth/registration', params: {
      identifier: 'open@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      invite_token: invitation.token
    }

    assert_response :redirect
    invitation.reload
    assert_equal 1, invitation.uses_count
  end

  test 'form registration in open mode without token succeeds normally' do
    RSB::Settings.set('auth.registration_mode', 'open')

    post '/auth/registration', params: {
      identifier: 'normal@example.com',
      password: 'password1234',
      password_confirmation: 'password1234'
    }

    assert_response :redirect
    identity = RSB::Auth::Identity.last
    assert_nil identity.metadata['invitation_id']
  end

  # --- Multi-use token ---

  test 'multi-use invitation token can be used by multiple registrations' do
    RSB::Settings.set('auth.registration_mode', 'invite_only')
    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now, max_uses: 3)

    3.times do |i|
      post '/auth/registration', params: {
        identifier: "user#{i}@example.com",
        password: 'password1234',
        password_confirmation: 'password1234',
        invite_token: invitation.token
      }
      assert_response :redirect
    end

    invitation.reload
    assert_equal 3, invitation.uses_count
    assert invitation.exhausted?

    # 4th attempt should fail
    post '/auth/registration', params: {
      identifier: 'user4@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      invite_token: invitation.token
    }
    assert_response :unprocessable_entity
  end

  # --- Lifecycle hook integration ---

  test 'after_invitation_used lifecycle hook fires on registration with token' do
    RSB::Settings.set('auth.registration_mode', 'invite_only')
    invitation = RSB::Auth::Invitation.create!(
      expires_at: 7.days.from_now,
      max_uses: 1,
      metadata: { 'plan' => 'pro' }
    )

    hook_called = false
    hook_metadata = nil

    custom_handler = Class.new(RSB::Auth::LifecycleHandler) do
      define_method(:after_invitation_used) do |inv, _identity|
        hook_called = true
        hook_metadata = inv.metadata
      end
    end
    Object.const_set(:CrossGemTestHandler, custom_handler)
    RSB::Auth.configure { |c| c.lifecycle_handler = 'CrossGemTestHandler' }

    post '/auth/registration', params: {
      identifier: 'hook@example.com',
      password: 'password1234',
      password_confirmation: 'password1234',
      invite_token: invitation.token
    }

    assert hook_called, 'after_invitation_used hook should have fired'
    assert_equal 'pro', hook_metadata['plan']
  ensure
    RSB::Auth.configure { |c| c.lifecycle_handler = nil }
    Object.send(:remove_const, :CrossGemTestHandler) if defined?(::CrossGemTestHandler)
  end

  # --- Admin invitation management (cross-gem) ---

  test 'admin can create invitation and deliver it' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    # Create invitation
    assert_difference 'RSB::Auth::Invitation.count', 1 do
      post '/admin/invitations', params: {
        label: 'Cross-gem test',
        max_uses: '1',
        expires_in_hours: '72'
      }
    end
    assert_response :redirect

    invitation = RSB::Auth::Invitation.last
    assert_equal 'Cross-gem test', invitation.label
    assert_equal admin, invitation.invited_by

    # Deliver it
    assert_enqueued_emails 1 do
      post "/admin/invitations/#{invitation.id}/deliver", params: {
        recipient: 'admin-invite@example.com',
        channel: 'email'
      }
    end

    assert_equal 1, invitation.deliveries.count
  end

  # --- Notifier registry cross-gem ---

  test 'notifier registry is populated with Email notifier' do
    assert RSB::Auth.notifiers.find(:email), 'Email notifier should be registered'
    assert_equal RSB::Auth::InvitationNotifier::Email, RSB::Auth.notifiers.find(:email)
  end

  test 'notifier registry keys include :email' do
    assert_includes RSB::Auth.notifiers.keys, :email
  end

  test 'admin deliver uses notifier registry and creates delivery without notifier_class column' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now, max_uses: 1)

    assert_enqueued_emails 1 do
      post "/admin/invitations/#{invitation.id}/deliver", params: {
        channel: 'email',
        recipient: 'registry-test@example.com',
        subject: 'Custom Subject',
        message: 'Join us!'
      }
    end

    assert_response :redirect
    delivery = invitation.deliveries.last
    assert_equal 'registry-test@example.com', delivery.recipient
    assert_equal 'email', delivery.channel
    assert delivery.delivered_at.present?

    # Verify notifier_class column no longer exists
    refute RSB::Auth::InvitationDelivery.column_names.include?('notifier_class'),
           'notifier_class column should have been removed'
    refute RSB::Auth::InvitationDelivery.column_names.include?('notifier_method'),
           'notifier_method column should have been removed'
  end

  test 'admin deliver with unregistered channel returns error' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now, max_uses: 1)

    post "/admin/invitations/#{invitation.id}/deliver", params: {
      channel: 'telegram',
      recipient: '@user'
    }

    assert_response :redirect
    follow_redirect!
    assert_match(/no notifier/i, flash[:alert])
  end

  test 'admin redeliver works with registry-based service' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now, max_uses: 1)

    # First delivery
    post "/admin/invitations/#{invitation.id}/deliver", params: {
      channel: 'email',
      recipient: 'redeliver-test@example.com'
    }
    delivery = invitation.deliveries.last

    # Redeliver (after rate limit window)
    travel 2.minutes do
      assert_enqueued_emails 1 do
        post "/admin/invitations/#{invitation.id}/redeliver", params: {
          delivery_id: delivery.id
        }
      end
      assert_response :redirect
    end
  end

  test 'custom notifier can be registered and used for delivery' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    # Register a custom test notifier
    delivered_to = nil
    test_notifier = Class.new(RSB::Auth::InvitationNotifier::Base) do
      define_singleton_method(:channel_key) { :test_integration }
      define_singleton_method(:label) { 'Test Integration' }
      define_singleton_method(:form_fields) do
        [{ key: :recipient, type: :text, label: 'Test Recipient', required: true, recipient: true }]
      end
      define_method(:deliver!) do |_invitation, fields: {}|
        delivered_to = fields[:recipient]
      end
    end
    RSB::Auth.notifiers.register(test_notifier)

    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now, max_uses: 1)

    post "/admin/invitations/#{invitation.id}/deliver", params: {
      channel: 'test_integration',
      recipient: 'custom-channel-user'
    }

    assert_response :redirect
    assert_equal 'custom-channel-user', delivered_to

    delivery = invitation.deliveries.last
    assert_equal 'test_integration', delivery.channel
    assert_equal 'custom-channel-user', delivery.recipient
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
