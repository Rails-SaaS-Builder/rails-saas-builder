# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    module InvitationNotifier
      class BaseTest < ActiveSupport::TestCase
        test 'channel_key raises NotImplementedError on Base' do
          assert_raises(NotImplementedError) { Base.channel_key }
        end

        test 'form_fields raises NotImplementedError on Base' do
          assert_raises(NotImplementedError) { Base.form_fields }
        end

        test 'deliver! raises NotImplementedError on Base instance' do
          instance = Base.new
          assert_raises(NotImplementedError) do
            instance.deliver!(nil, fields: {})
          end
        end

        test 'label defaults to titleized channel_key' do
          notifier = Class.new(Base) do
            def self.channel_key = :sms_gateway
            def self.form_fields = []
          end
          assert_equal 'Sms Gateway', notifier.label
        end

        test 'recipient_field returns the field with recipient: true' do
          notifier = Class.new(Base) do
            def self.channel_key = :test

            def self.form_fields
              [
                { key: :recipient, type: :email, label: 'Email', recipient: true },
                { key: :message, type: :textarea, label: 'Msg' }
              ]
            end
          end
          field = notifier.recipient_field
          assert_equal :recipient, field[:key]
          assert field[:recipient]
        end

        test 'recipient_field returns nil when no field marked as recipient' do
          notifier = Class.new(Base) do
            def self.channel_key = :test

            def self.form_fields
              [{ key: :body, type: :text, label: 'Body' }]
            end
          end
          assert_nil notifier.recipient_field
        end
      end
    end
  end
end
