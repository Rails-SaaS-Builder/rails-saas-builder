# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    module InvitationNotifier
      class EmailTest < ActiveSupport::TestCase
        include ActionMailer::TestHelper

        setup do
          register_auth_settings
        end

        test 'channel_key is :email' do
          assert_equal :email, Email.channel_key
        end

        test 'label is "Email"' do
          assert_equal 'Email', Email.label
        end

        test 'form_fields includes recipient, subject, and message' do
          fields = Email.form_fields
          assert_equal 3, fields.size

          recipient = fields.find { |f| f[:key] == :recipient }
          assert recipient
          assert_equal :email, recipient[:type]
          assert recipient[:required]
          assert recipient[:recipient]

          subject_field = fields.find { |f| f[:key] == :subject }
          assert subject_field
          assert_equal :text, subject_field[:type]
          refute subject_field[:required]

          message_field = fields.find { |f| f[:key] == :message }
          assert message_field
          assert_equal :textarea, message_field[:type]
          refute message_field[:required]
        end

        test 'recipient_field returns the :recipient field' do
          field = Email.recipient_field
          assert_equal :recipient, field[:key]
          assert_equal :email, field[:type]
          assert field[:recipient]
        end

        test 'deliver! calls AuthMailer.invitation and delivers later' do
          invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now)
          notifier = Email.new

          assert_enqueued_emails(1) do
            notifier.deliver!(invitation, fields: { recipient: 'test@example.com' })
          end
        end

        test 'deliver! passes subject and message kwargs to AuthMailer' do
          invitation = RSB::Auth::Invitation.create!(expires_at: 7.days.from_now)
          notifier = Email.new

          assert_enqueued_emails(1) do
            notifier.deliver!(invitation, fields: {
                                recipient: 'test@example.com',
                                subject: 'Custom Subject',
                                message: 'Join us at %{invite_url}' # rubocop:disable Style/FormatStringToken
                              })
          end
        end

        test 'is a subclass of Base' do
          assert Email < Base
        end
      end
    end
  end
end
