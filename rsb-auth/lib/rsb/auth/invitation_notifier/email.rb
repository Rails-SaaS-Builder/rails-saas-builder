# frozen_string_literal: true

module RSB
  module Auth
    module InvitationNotifier
      # Built-in email notifier for invitation delivery via ActionMailer.
      # Sends invitation emails through {RSB::Auth::AuthMailer#invitation}
      # with optional custom subject and message body.
      class Email < Base
        # @return [Symbol] :email
        def self.channel_key = :email

        # @return [String] "Email"
        def self.label = 'Email'

        # @return [Array<Hash>] recipient (email), subject (text), message (textarea)
        def self.form_fields
          [
            { key: :recipient, type: :email, label: 'Email address', required: true,
              placeholder: 'user@example.com', recipient: true },
            { key: :subject, type: :text, label: 'Subject', required: false,
              default: "You've been invited", placeholder: 'Email subject line' },
            { key: :message, type: :textarea, label: 'Message', required: false,
              placeholder: 'Custom message body. Use %{invite_url} for the invitation link.' } # rubocop:disable Style/FormatStringToken
          ]
        end

        # Sends invitation email via AuthMailer with optional custom subject/message.
        #
        # @param invitation [Invitation] the invitation to deliver
        # @param fields [Hash] :recipient (required), :subject, :message (optional)
        def deliver!(invitation, fields: {})
          mail = RSB::Auth::AuthMailer.invitation(
            invitation, fields[:recipient],
            subject: fields[:subject], message: fields[:message]
          )
          mail.deliver_later
        end
      end
    end
  end
end
