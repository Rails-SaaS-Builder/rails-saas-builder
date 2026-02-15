# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class InvitationServiceTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth',
                             password_min_length: 8,
                             session_duration: 86_400,
                             login_identifier: 'email',
                             registration_mode: 'open',
                             verification_required: false)
        RSB::Auth.credentials.register(
          RSB::Auth::CredentialDefinition.new(
            key: :email_password,
            class_name: 'RSB::Auth::Credential::EmailPassword'
          )
        )
        @service = RSB::Auth::InvitationService.new
      end

      test 'create creates invitation and enqueues email' do
        assert_difference 'RSB::Auth::Invitation.count', 1 do
          result = @service.create(email: 'invitee@example.com')
          assert result.success?
          assert_equal 'invitee@example.com', result.invitation.email
        end
      end

      test 'create with invalid email returns failure' do
        result = @service.create(email: 'invalid')
        assert_not result.success?
        assert result.error.present?
      end

      test 'accept creates identity and credential' do
        invitation = RSB::Auth::Invitation.create!(email: 'invitee@example.com')

        result = @service.accept(
          token: invitation.token,
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert result.success?
        assert_instance_of RSB::Auth::Identity, result.identity
        assert invitation.reload.accepted?
      end

      test 'accept pre-verifies credential' do
        invitation = RSB::Auth::Invitation.create!(email: 'invitee@example.com')

        result = @service.accept(
          token: invitation.token,
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        credential = result.identity.primary_credential
        assert credential.verified?
      end

      test 'accept with invalid token returns failure' do
        result = @service.accept(
          token: 'invalid-token',
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert_not result.success?
        assert_equal 'Invalid or expired invitation.', result.error
      end

      test 'accept with expired invitation returns failure' do
        invitation = RSB::Auth::Invitation.create!(email: 'invitee@example.com')
        invitation.update_columns(expires_at: 1.hour.ago)

        result = @service.accept(
          token: invitation.token,
          password: 'password1234',
          password_confirmation: 'password1234'
        )

        assert_not result.success?
        assert_equal 'Invalid or expired invitation.', result.error
      end
    end
  end
end
