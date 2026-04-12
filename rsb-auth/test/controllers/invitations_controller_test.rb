# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class InvitationsControllerTest < ActionDispatch::IntegrationTest
      include RSB::Auth::Engine.routes.url_helpers

      setup do
        register_auth_settings
        register_all_auth_credentials
        RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
      end

      test 'GET /invitations/:token redirects to registration with invite_token' do
        invitation = create_test_invitation
        get accept_invitation_path(invitation.token)

        assert_redirected_to new_registration_path(invite_token: invitation.token)
      end

      test 'GET /invitations/:token with invalid token still redirects' do
        get accept_invitation_path('nonexistent-token')

        assert_redirected_to new_registration_path(invite_token: 'nonexistent-token')
      end

      test 'PATCH /invitations/:token is no longer routable' do
        invitation = create_test_invitation
        patch "/auth/invitations/#{invitation.token}", params: { password: 'test1234' }
        assert_response :not_found
      end

      private

      def default_url_options
        { host: 'localhost' }
      end
    end
  end
end
