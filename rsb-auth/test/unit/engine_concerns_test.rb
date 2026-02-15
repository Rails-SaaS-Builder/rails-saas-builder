# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class EngineConcernsTest < ActiveSupport::TestCase
      test 'identity concern is applied via to_prepare' do
        concern = Module.new do
          extend ActiveSupport::Concern
          def custom_identity_method
            'from_concern'
          end
        end

        RSB::Auth.configuration.identity_concerns << concern
        # Simulate to_prepare by manually applying (engine uses prepend for identity concerns)
        RSB::Auth::Identity.prepend(concern)

        identity = RSB::Auth::Identity.create!
        assert_equal 'from_concern', identity.custom_identity_method
      end

      test 'credential concern is applied to base class' do
        concern = Module.new do
          extend ActiveSupport::Concern
          def custom_credential_method
            'from_concern'
          end
        end

        RSB::Auth.configuration.credential_concerns << concern
        RSB::Auth::Credential.include(concern)

        identity = RSB::Auth::Identity.create!
        cred = identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'concern-test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert_equal 'from_concern', cred.custom_credential_method
      end

      test 'credential concern is inherited by STI subtypes' do
        concern = Module.new do
          extend ActiveSupport::Concern
          def sti_test_method
            'inherited'
          end
        end

        RSB::Auth::Credential.include(concern)

        identity = RSB::Auth::Identity.create!
        email_cred = identity.credentials.create!(
          type: 'RSB::Auth::Credential::EmailPassword',
          identifier: 'sti-test@example.com',
          password: 'password1234',
          password_confirmation: 'password1234'
        )
        assert_equal 'inherited', email_cred.sti_test_method
      end

      test 'identity concern can override complete?' do
        concern = Module.new do
          extend ActiveSupport::Concern
          def complete?
            metadata['name'].present?
          end
        end

        # Use a subclass so we don't pollute the global Identity (prepend would leak into other tests)
        identity_klass = Class.new(RSB::Auth::Identity) do
          prepend concern
        end
        identity_klass.table_name = RSB::Auth::Identity.table_name

        identity = identity_klass.create!(metadata: {})
        assert_not identity.complete?

        identity.update!(metadata: { 'name' => 'Alice' })
        assert identity.complete?
      end

      test 'concerns are applied in array order — last one wins' do
        concern_a = Module.new do
          extend ActiveSupport::Concern
          def order_test
            'a'
          end
        end

        concern_b = Module.new do
          extend ActiveSupport::Concern
          def order_test
            'b'
          end
        end

        # Engine uses prepend for identity concerns; last in array wins
        RSB::Auth::Identity.prepend(concern_a)
        RSB::Auth::Identity.prepend(concern_b)

        identity = RSB::Auth::Identity.create!
        assert_equal 'b', identity.order_test
      end

      test 'double-include does not raise' do
        concern = Module.new do
          extend ActiveSupport::Concern
        end

        assert_nothing_raised do
          RSB::Auth::Identity.prepend(concern)
          RSB::Auth::Identity.prepend(concern)
        end
      end

      setup do
        register_test_schema('auth', password_min_length: 8, session_duration: 86_400)
      end
    end
  end
end
