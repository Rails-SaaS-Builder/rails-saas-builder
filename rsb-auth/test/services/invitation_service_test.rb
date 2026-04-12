# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class InvitationServiceTest < ActiveSupport::TestCase
      include ActionMailer::TestHelper

      setup do
        register_auth_settings
        register_notifiers
        @service = InvitationService.new
      end

      # --- create ---

      test 'create creates invitation with defaults from settings' do
        result = @service.create
        assert result.success?
        assert result.invitation.persisted?
        assert result.invitation.token.present?
        assert_equal 1, result.invitation.max_uses # default from setting
        assert_equal 0, result.invitation.uses_count
        assert_in_delta 168.hours.from_now.to_i, result.invitation.expires_at.to_i, 5
      end

      test 'create with explicit params overrides defaults' do
        result = @service.create(
          label: 'VIP batch',
          max_uses: 10,
          expires_in: 48.hours,
          metadata: { 'plan' => 'enterprise' }
        )
        assert result.success?
        assert_equal 'VIP batch', result.invitation.label
        assert_equal 10, result.invitation.max_uses
        assert_equal({ 'plan' => 'enterprise' }, result.invitation.metadata)
        assert_in_delta 48.hours.from_now.to_i, result.invitation.expires_at.to_i, 5
      end

      test 'create with max_uses 0 stores nil (unlimited)' do
        result = @service.create(max_uses: 0)
        assert result.success?
        assert_nil result.invitation.max_uses
      end

      test 'create with invited_by stores polymorphic reference' do
        identity = RSB::Auth::Identity.create!(status: :active)
        result = @service.create(invited_by: identity)
        assert result.success?
        assert_equal identity, result.invitation.invited_by
      end

      test 'create does NOT send any email' do
        assert_no_enqueued_emails do
          @service.create
        end
      end

      test 'create fails if expiry is less than 1 hour' do
        result = @service.create(expires_in: 30.minutes)
        refute result.success?
        assert_match(/expiry/i, result.error)
      end

      test 'create fails if expiry exceeds 365 days' do
        result = @service.create(expires_in: 8761.hours)
        refute result.success?
        assert_match(/expiry/i, result.error)
      end

      test 'create with expires_in 0 creates non-expiring invitation' do
        result = @service.create(expires_in: 0)
        assert result.success?
        assert_nil result.invitation.expires_at
      end

      test 'create with expires_in :never creates non-expiring invitation' do
        result = @service.create(expires_in: :never)
        assert result.success?
        assert_nil result.invitation.expires_at
      end

      # --- deliver ---

      test 'deliver sends email via registry Email notifier and creates delivery record' do
        invitation = create_test_invitation
        result = nil

        assert_enqueued_emails(1) do
          result = @service.deliver(invitation, channel: 'email', fields: { recipient: 'user@example.com' })
        end

        assert result.success?
        assert result.delivery.persisted?
        assert_equal 'user@example.com', result.delivery.recipient
        assert_equal 'email', result.delivery.channel
        assert result.delivery.delivered_at.present?
      end

      test 'deliver with custom registered notifier' do
        # Create and register a test notifier
        delivered_args = nil
        test_notifier = Class.new(RSB::Auth::InvitationNotifier::Base) do
          define_singleton_method(:channel_key) { :telegram }
          define_singleton_method(:form_fields) do
            [
              { key: :recipient, type: :text, label: 'Chat ID', required: true, recipient: true },
              { key: :message, type: :textarea, label: 'Message' }
            ]
          end
          define_method(:deliver!) do |invitation, fields: {}|
            delivered_args = { invitation: invitation, fields: fields }
          end
        end
        RSB::Auth.notifiers.register(test_notifier)

        invitation = create_test_invitation
        result = @service.deliver(
          invitation,
          channel: 'telegram',
          fields: { recipient: '@user123', message: 'Welcome!' }
        )

        assert result.success?
        assert_equal 'telegram', result.delivery.channel
        assert_equal '@user123', result.delivery.recipient
        assert delivered_args
        assert_equal invitation, delivered_args[:invitation]
        assert_equal '@user123', delivered_args[:fields][:recipient]
      end

      test 'deliver fails if channel is not registered in notifier registry' do
        invitation = create_test_invitation
        result = @service.deliver(invitation, channel: 'nonexistent', fields: { recipient: 'x' })

        refute result.success?
        assert_match(/no notifier/i, result.error)
      end

      test 'deliver extracts recipient from notifier recipient_field' do
        invitation = create_test_invitation
        result = @service.deliver(invitation, channel: 'email', fields: {
                                    recipient: 'extracted@example.com',
                                    subject: 'Test'
                                  })

        assert result.success?
        assert_equal 'extracted@example.com', result.delivery.recipient
      end

      test 'deliver defaults channel to email' do
        invitation = create_test_invitation
        result = @service.deliver(invitation, fields: { recipient: 'default@example.com' })

        assert result.success?
        assert_equal 'email', result.delivery.channel
      end

      test 'deliver fails if invitation is not pending' do
        invitation = create_test_invitation
        invitation.revoke!

        result = @service.deliver(invitation, channel: 'email', fields: { recipient: 'user@example.com' })
        refute result.success?
        assert_match(/not pending/i, result.error)
      end

      test 'deliver rate limits: fails if < 1 minute since last delivery for same recipient+channel' do
        invitation = create_test_invitation

        @service.deliver(invitation, channel: 'email', fields: { recipient: 'user@example.com' })

        result = @service.deliver(invitation, channel: 'email', fields: { recipient: 'user@example.com' })
        refute result.success?
        assert_match(/wait/i, result.error)
      end

      test 'deliver rate limit allows different recipients' do
        invitation = create_test_invitation
        @service.deliver(invitation, channel: 'email', fields: { recipient: 'user1@example.com' })

        result = @service.deliver(invitation, channel: 'email', fields: { recipient: 'user2@example.com' })
        assert result.success?
      end

      test 'deliver rate limit allows different channels' do
        invitation = create_test_invitation
        @service.deliver(invitation, channel: 'email', fields: { recipient: 'user@example.com' })

        # Register a second notifier for SMS
        sms_notifier = Class.new(RSB::Auth::InvitationNotifier::Base) do
          define_singleton_method(:channel_key) { :sms }
          define_singleton_method(:form_fields) do
            [{ key: :recipient, type: :text, label: 'Phone', required: true, recipient: true }]
          end
          define_method(:deliver!) { |_inv, **| nil }
        end
        RSB::Auth.notifiers.register(sms_notifier)

        result = @service.deliver(
          invitation,
          channel: 'sms',
          fields: { recipient: 'user@example.com' }
        )
        assert result.success?
      end

      # --- redeliver ---

      test 'redeliver re-sends using same delivery channel and recipient' do
        invitation = create_test_invitation
        original = @service.deliver(invitation, channel: 'email', fields: { recipient: 'user@example.com' })

        travel 2.minutes do
          result = @service.redeliver(original.delivery)
          assert result.success?
          assert result.delivery.persisted?
          assert_equal 'user@example.com', result.delivery.recipient
          assert_equal 'email', result.delivery.channel
        end
      end

      test 'redeliver fails when rate limited (< 1 minute)' do
        invitation = create_test_invitation
        original = @service.deliver(invitation, channel: 'email', fields: { recipient: 'user@example.com' })

        result = @service.redeliver(original.delivery)
        refute result.success?
        assert_match(/wait/i, result.error)
      end

      test 'redeliver fails when invitation is not pending' do
        invitation = create_test_invitation
        original = @service.deliver(invitation, channel: 'email', fields: { recipient: 'user@example.com' })
        invitation.revoke!

        travel 2.minutes do
          result = @service.redeliver(original.delivery)
          refute result.success?
          assert_match(/not pending/i, result.error)
        end
      end

      # --- extend_expiry ---

      test 'extend_expiry adds hours to expires_at' do
        invitation = create_test_invitation
        original_expiry = invitation.expires_at

        result = @service.extend_expiry(invitation, hours: 24)
        assert result.success?
        assert_in_delta (original_expiry + 24.hours).to_i, result.invitation.expires_at.to_i, 2
      end

      test 'extend_expiry fails for non-pending invitation' do
        invitation = create_test_invitation
        invitation.revoke!

        result = @service.extend_expiry(invitation, hours: 24)
        refute result.success?
        assert_match(/not pending/i, result.error)
      end

      test 'extend_expiry fails if total exceeds 365 days from creation' do
        invitation = create_test_invitation(expires_in: 364.days)

        result = @service.extend_expiry(invitation, hours: 48)
        refute result.success?
        assert_match(/exceed/i, result.error)
      end

      test 'extend_expiry fails for non-expiring invitation' do
        result = @service.create(expires_in: 0)
        extend_result = @service.extend_expiry(result.invitation, hours: 24)
        refute extend_result.success?
        assert_match(/non-expiring/i, extend_result.error)
      end

      # --- create_and_deliver ---

      test 'create_and_deliver creates invitation and delivers in one call' do
        result = nil
        assert_enqueued_emails(1) do
          result = @service.create_and_deliver(
            channel: 'email',
            fields: { recipient: 'user@example.com' },
            label: 'Quick invite'
          )
        end

        assert result.success?
        assert result.invitation.persisted?
        assert result.delivery.persisted?
        assert_equal 'Quick invite', result.invitation.label
      end

      test 'create_and_deliver returns error if create fails' do
        result = @service.create_and_deliver(
          channel: 'email',
          fields: { recipient: 'user@example.com' },
          expires_in: 10.seconds # too short
        )
        refute result.success?
        assert_match(/expiry/i, result.error)
      end
    end
  end
end
