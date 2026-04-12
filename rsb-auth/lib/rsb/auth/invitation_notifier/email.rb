# frozen_string_literal: true

module RSB
  module Auth
    module InvitationNotifier
      class Email < Base
        def self.channel_key = :email
        def self.label = 'Email'

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
