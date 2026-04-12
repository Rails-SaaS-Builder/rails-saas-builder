# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class InvitationDeliveryTest < ActiveSupport::TestCase
      setup do
        register_auth_settings
        @invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now)
      end

      test 'belongs to invitation' do
        delivery = InvitationDelivery.create!(
          invitation: @invitation,
          recipient: 'user@example.com',
          channel: 'email',
          delivered_at: Time.current
        )
        assert_equal @invitation, delivery.invitation
      end

      test 'requires invitation' do
        delivery = InvitationDelivery.new(
          recipient: 'user@example.com',
          channel: 'email',
          delivered_at: Time.current
        )
        refute delivery.valid?
      end

      test 'requires recipient' do
        delivery = InvitationDelivery.new(
          invitation: @invitation,
          channel: 'email',
          delivered_at: Time.current
        )
        refute delivery.valid?
      end

      test 'requires channel' do
        delivery = InvitationDelivery.new(
          invitation: @invitation,
          recipient: 'user@example.com',
          delivered_at: Time.current
        )
        refute delivery.valid?
      end

      test 'requires delivered_at' do
        delivery = InvitationDelivery.new(
          invitation: @invitation,
          recipient: 'user@example.com',
          channel: 'email'
        )
        refute delivery.valid?
      end

      test 'invitation has_many deliveries with dependent destroy' do
        InvitationDelivery.create!(
          invitation: @invitation,
          recipient: 'user@example.com',
          channel: 'email',
          delivered_at: Time.current
        )
        assert_equal 1, @invitation.deliveries.count
        @invitation.destroy!
        assert_equal 0, InvitationDelivery.count
      end
    end
  end
end
