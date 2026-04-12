# frozen_string_literal: true

module RSB
  module Auth
    # Service for invitation token CRUD and notification delivery.
    # Creates tokens without sending, delivers via pluggable notifiers
    # (resolved from {NotifierRegistry}), supports redelivery with rate
    # limiting, and expiry extension.
    #
    # @example Create and deliver an invitation
    #   service = RSB::Auth::InvitationService.new
    #   result = service.create_and_deliver(
    #     channel: 'email',
    #     fields: { recipient: 'user@example.com', subject: 'Welcome!' }
    #   )
    class InvitationService
      # @!attribute [r] success?
      #   @return [Boolean]
      # @!attribute [r] invitation
      #   @return [Invitation, nil]
      # @!attribute [r] error
      #   @return [String, nil]
      CreateResult = Data.define(:success?, :invitation, :error)

      # @!attribute [r] success?
      #   @return [Boolean]
      # @!attribute [r] delivery
      #   @return [InvitationDelivery, nil]
      # @!attribute [r] error
      #   @return [String, nil]
      DeliverResult = Data.define(:success?, :delivery, :error)

      # @!attribute [r] success?
      #   @return [Boolean]
      # @!attribute [r] invitation
      #   @return [Invitation, nil]
      # @!attribute [r] delivery
      #   @return [InvitationDelivery, nil]
      # @!attribute [r] error
      #   @return [String, nil]
      CreateAndDeliverResult = Data.define(:success?, :invitation, :delivery, :error)

      # Creates an invitation token. Does NOT send any notification.
      #
      # @param invited_by [Object, nil] polymorphic reference to inviter
      # @param expires_in [Integer, ActiveSupport::Duration, nil] override expiry (nil = read from setting)
      # @param max_uses [Integer, nil] override max uses (nil = read from setting, 0 = unlimited)
      # @param label [String, nil] human-readable admin-only note
      # @param metadata [Hash] arbitrary data for host app use
      # @return [CreateResult]
      def create(invited_by: nil, expires_in: nil, max_uses: nil, label: nil, metadata: {})
        expiry_seconds = resolve_expiry(expires_in)
        unless valid_expiry?(expiry_seconds)
          return create_failure('Expiry must be between 1 hour and 8760 hours (365 days)')
        end

        resolved_max_uses = resolve_max_uses(max_uses)
        expires_at = expiry_seconds&.seconds&.from_now

        invitation = Invitation.create!(
          invited_by: invited_by,
          expires_at: expires_at,
          max_uses: resolved_max_uses,
          label: label,
          metadata: metadata || {}
        )

        CreateResult.new(success?: true, invitation: invitation, error: nil)
      rescue ActiveRecord::RecordInvalid => e
        create_failure(e.record.errors.full_messages.join(', '))
      end

      # Delivers an invitation notification via the specified channel.
      #
      # @param invitation [Invitation] the invitation to deliver
      # @param channel [String] notifier channel key (default: "email")
      # @param fields [Hash] all notifier form field values (includes recipient, message, etc.)
      # @return [DeliverResult]
      def deliver(invitation, channel: 'email', fields: {})
        return deliver_failure('Invitation is not pending') unless invitation.pending?

        notifier = RSB::Auth.notifiers.find(channel)
        return deliver_failure("No notifier registered for channel '#{channel}'") unless notifier

        recipient_field = notifier.recipient_field
        recipient = fields[recipient_field[:key]] if recipient_field

        if recipient.blank?
          return deliver_failure('Recipient is required')
        end

        if rate_limited?(invitation, recipient, channel)
          return deliver_failure('Please wait before resending')
        end

        notifier.new.deliver!(invitation, fields: fields)

        delivery = InvitationDelivery.create!(
          invitation: invitation,
          recipient: recipient,
          channel: channel,
          delivered_at: Time.current
        )

        DeliverResult.new(success?: true, delivery: delivery, error: nil)
      end

      # Convenience: creates an invitation and delivers it in one call.
      #
      # @param channel [String] notifier channel key (default: "email")
      # @param fields [Hash] all notifier form field values (includes recipient)
      # @param invited_by [Object, nil] polymorphic reference to inviter
      # @param expires_in [Integer, Duration, nil] override expiry
      # @param max_uses [Integer, nil] override max uses
      # @param label [String, nil] admin-only note
      # @param metadata [Hash] arbitrary data
      # @return [CreateAndDeliverResult]
      def create_and_deliver(channel: 'email', fields: {},
                             invited_by: nil, expires_in: nil, max_uses: nil, label: nil, metadata: {})
        create_result = create(
          invited_by: invited_by,
          expires_in: expires_in,
          max_uses: max_uses,
          label: label,
          metadata: metadata
        )

        unless create_result.success?
          return CreateAndDeliverResult.new(
            success?: false, invitation: nil, delivery: nil, error: create_result.error
          )
        end

        deliver_result = deliver(
          create_result.invitation,
          channel: channel,
          fields: fields
        )

        CreateAndDeliverResult.new(
          success?: deliver_result.success?,
          invitation: create_result.invitation,
          delivery: deliver_result.success? ? deliver_result.delivery : nil,
          error: deliver_result.error
        )
      end

      # Re-delivers a previous delivery using the same recipient/channel.
      # Reconstructs fields from the stored delivery record.
      #
      # @param delivery [InvitationDelivery] the delivery record to re-send
      # @return [DeliverResult]
      def redeliver(delivery)
        deliver(
          delivery.invitation,
          channel: delivery.channel,
          fields: { recipient: delivery.recipient }
        )
      end

      # Extends an invitation's expiry by the given number of hours.
      #
      # @param invitation [Invitation] the invitation to extend
      # @param hours [Integer] number of hours to add
      # @return [CreateResult]
      def extend_expiry(invitation, hours:)
        return create_failure('Invitation is not pending') unless invitation.pending?
        return create_failure('Cannot extend expiry for non-expiring invitations') if invitation.expires_at.nil?

        new_expiry = invitation.expires_at + hours.hours
        max_allowed = invitation.created_at + 8760.hours

        if new_expiry > max_allowed
          return create_failure('Extended expiry would exceed 365 days from creation')
        end

        invitation.update!(expires_at: new_expiry)
        CreateResult.new(success?: true, invitation: invitation, error: nil)
      end

      private

      def resolve_expiry(expires_in)
        if [0, :never].include?(expires_in)
          nil # no expiry
        elsif expires_in
          expires_in.to_i
        else
          hours = RSB::Settings.get('auth.invitation_expiry_hours') || 168
          hours * 3600
        end
      end

      def resolve_max_uses(max_uses)
        if max_uses.nil?
          default = RSB::Settings.get('auth.invitation_default_max_uses') || 1
          default.zero? ? nil : default
        elsif max_uses.zero?
          nil # unlimited
        else
          max_uses
        end
      end

      def valid_expiry?(seconds)
        return true if seconds.nil?

        seconds >= 3600 && seconds <= 8760 * 3600
      end

      def rate_limited?(invitation, recipient, channel)
        InvitationDelivery
          .where(invitation: invitation, recipient: recipient, channel: channel)
          .where('delivered_at > ?', 1.minute.ago)
          .exists?
      end

      def create_failure(error)
        CreateResult.new(success?: false, invitation: nil, error: error)
      end

      def deliver_failure(error)
        DeliverResult.new(success?: false, delivery: nil, error: error)
      end
    end
  end
end
