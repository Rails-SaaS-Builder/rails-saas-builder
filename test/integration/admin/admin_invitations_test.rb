# frozen_string_literal: true

require 'test_helper'

class AdminInvitationsTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_notifiers
    register_all_admin_categories
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # --- Index ---

  test 'admin invitation index lists invitations' do
    RSB::Auth::Invitation.create!(expires_at: 7.days.from_now, label: 'Test batch', max_uses: 5)

    get '/admin/invitations'
    assert_response :success
    assert_match 'Test batch', response.body
  end

  test 'admin invitation index shows status badges' do
    RSB::Auth::Invitation.create!(expires_at: 7.days.from_now)
    RSB::Auth::Invitation.create!(expires_at: 1.hour.ago)
    RSB::Auth::Invitation.create!(expires_at: 7.days.from_now, revoked_at: Time.current)

    get '/admin/invitations'
    assert_response :success
    assert_match 'pending', response.body
    assert_match 'expired', response.body
    assert_match 'revoked', response.body
  end

  # --- Show ---

  test 'admin invitation show displays all fields' do
    invitation = RSB::Auth::Invitation.create!(
      expires_at: 7.days.from_now,
      label: 'VIP invite',
      max_uses: 10,
      metadata: { 'plan' => 'pro' }
    )

    get "/admin/invitations/#{invitation.id}"
    assert_response :success
    assert_match 'VIP invite', response.body
    assert_match invitation.token, response.body
  end

  test 'admin invitation show displays delivery history' do
    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now)
    RSB::Auth::InvitationDelivery.create!(
      invitation: invitation,
      recipient: 'user@example.com',
      channel: 'email',
      delivered_at: Time.current
    )

    get "/admin/invitations/#{invitation.id}"
    assert_response :success
    assert_match 'user@example.com', response.body
  end

  # --- New / Create ---

  test 'admin invitation new renders form' do
    get '/admin/invitations/new'
    assert_response :success
  end

  test 'admin invitation create creates invitation' do
    assert_difference 'RSB::Auth::Invitation.count', 1 do
      post '/admin/invitations', params: {
        label: 'New invite',
        max_uses: '5',
        expires_in_hours: '72',
        metadata: '{"plan":"starter"}'
      }
    end

    invitation = RSB::Auth::Invitation.last
    assert_equal 'New invite', invitation.label
    assert_equal 5, invitation.max_uses
    assert_equal({ 'plan' => 'starter' }, invitation.metadata)
    assert_redirected_to "/admin/invitations/#{invitation.id}"
  end

  # --- Revoke ---

  test 'admin invitation revoke sets revoked_at' do
    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now)
    assert_nil invitation.revoked_at

    post "/admin/invitations/#{invitation.id}/revoke"
    invitation.reload
    assert invitation.revoked_at.present?
    assert_redirected_to "/admin/invitations/#{invitation.id}"
  end

  # --- Deliver ---

  test 'admin invitation deliver sends notification and creates delivery' do
    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now)

    assert_difference 'RSB::Auth::InvitationDelivery.count', 1 do
      assert_enqueued_emails 1 do
        post "/admin/invitations/#{invitation.id}/deliver", params: {
          recipient: 'user@example.com',
          channel: 'email'
        }
      end
    end

    assert_redirected_to "/admin/invitations/#{invitation.id}"
  end

  # --- Redeliver ---

  test 'admin invitation redeliver resends delivery' do
    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now)
    delivery = RSB::Auth::InvitationDelivery.create!(
      invitation: invitation,
      recipient: 'user@example.com',
      channel: 'email',
      delivered_at: 2.minutes.ago
    )

    assert_enqueued_emails 1 do
      post "/admin/invitations/#{invitation.id}/redeliver", params: { delivery_id: delivery.id }
    end

    assert_redirected_to "/admin/invitations/#{invitation.id}"
  end

  # --- Extend Expiry ---

  test 'admin invitation extend_expiry extends expiry' do
    invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now)
    original_expiry = invitation.expires_at

    post "/admin/invitations/#{invitation.id}/extend_expiry", params: { hours: '24' }

    invitation.reload
    assert_in_delta (original_expiry + 24.hours).to_i, invitation.expires_at.to_i, 2
    assert_redirected_to "/admin/invitations/#{invitation.id}"
  end

  # --- RBAC ---

  test 'restricted admin cannot access invitations' do
    restricted = create_test_admin!(permissions: { 'other' => ['index'] })
    sign_in_admin(restricted)

    get '/admin/invitations'
    assert_includes [302, 403], response.status
  end

  # --- Filters ---

  test 'admin invitation index filters by status' do
    RSB::Auth::Invitation.create!(expires_at: 7.days.from_now, label: 'Pending one')
    RSB::Auth::Invitation.create!(expires_at: 1.hour.ago, label: 'Expired one')

    get '/admin/invitations', params: { q: { status: 'pending' } }
    assert_response :success
    assert_match 'Pending one', response.body
  end
end
