# frozen_string_literal: true

module RSB
  module Auth
    class AuthMailer < ApplicationMailer
      def verification(credential)
        @credential = credential
        @verification_url = engine_url_for(:verification_url, token: credential.verification_token)
        mail(to: credential.deliverable_email, subject: 'Verify your email address')
      end

      def password_reset(credential, reset_token)
        @credential = credential
        @reset_url = engine_url_for(:edit_password_reset_url, token: reset_token.token)
        mail(to: credential.deliverable_email, subject: 'Reset your password')
      end

      def invitation(invitation)
        @invitation = invitation
        @accept_url = engine_url_for(:accept_invitation_url, token: invitation.token)
        mail(to: invitation.email, subject: "You've been invited")
      end

      private

      def engine_url_for(route_name, **params)
        host = ActionMailer::Base.default_url_options[:host] || 'localhost'
        port = ActionMailer::Base.default_url_options[:port]
        RSB::Auth::Engine.routes.url_helpers.send(route_name, **params, host: host, port: port)
      end
    end
  end
end
