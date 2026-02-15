# frozen_string_literal: true

module RSB
  module Admin
    # Mailer for admin panel transactional emails.
    #
    # Uses the host app's ActionMailer configuration (SMTP settings, delivery method).
    # The `from` address is configurable via `RSB::Admin.configuration.mailer_sender`.
    #
    # @example Send verification email
    #   AdminMailer.email_verification(admin_user).deliver_later
    #
    class AdminMailer < ActionMailer::Base
      # Sends a verification link to the admin's pending email address.
      #
      # @param admin_user [AdminUser] must have `pending_email` and `email_verification_token` set
      # @return [Mail::Message]
      def email_verification(admin_user)
        @admin_user = admin_user
        @verification_url = verify_email_url(admin_user.email_verification_token)

        mail(
          to: admin_user.pending_email,
          from: RSB::Admin.configuration.mailer_sender,
          subject: 'Verify your new email address'
        )
      end

      private

      def verify_email_url(token)
        RSB::Admin::Engine.routes.url_helpers.verify_email_profile_url(token: token,
                                                                       host: default_url_options[:host] || 'localhost')
      end
    end
  end
end
