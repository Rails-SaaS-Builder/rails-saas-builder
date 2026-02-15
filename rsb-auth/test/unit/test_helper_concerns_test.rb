# frozen_string_literal: true

require 'test_helper'

module RSB
  module Auth
    class TestHelperConcernsTest < ActiveSupport::TestCase
      setup do
        register_test_schema('auth', password_min_length: 8, session_duration: 86_400)
      end

      test 'with_identity_concerns applies concern within block' do
        concern = Module.new do
          extend ActiveSupport::Concern
          def test_identity_helper_method
            'works'
          end
        end

        with_identity_concerns(concern) do
          identity = RSB::Auth::Identity.create!
          assert_equal 'works', identity.test_identity_helper_method
        end
      end

      test 'with_identity_concerns applies multiple concerns in order' do
        concern_a = Module.new do
          extend ActiveSupport::Concern
          def order_check
            'a'
          end
        end

        concern_b = Module.new do
          extend ActiveSupport::Concern
          def order_check
            'b'
          end
        end

        with_identity_concerns(concern_a, concern_b) do
          identity = RSB::Auth::Identity.create!
          assert_equal 'b', identity.order_check
        end
      end

      test 'with_identity_concerns can override complete?' do
        concern = Module.new do
          extend ActiveSupport::Concern
          def complete?
            false
          end
        end

        with_identity_concerns(concern) do
          identity = RSB::Auth::Identity.create!
          assert_not identity.complete?
        end
      end

      test 'with_credential_concerns applies concern within block' do
        concern = Module.new do
          extend ActiveSupport::Concern
          def test_credential_helper_method
            'works'
          end
        end

        with_credential_concerns(concern) do
          identity = RSB::Auth::Identity.create!
          cred = identity.credentials.create!(
            type: 'RSB::Auth::Credential::EmailPassword',
            identifier: 'helper-test@example.com',
            password: 'password1234',
            password_confirmation: 'password1234'
          )
          assert_equal 'works', cred.test_credential_helper_method
        end
      end

      test 'with_credential_concerns affects STI subtypes' do
        concern = Module.new do
          extend ActiveSupport::Concern
          def sti_helper_test
            'inherited'
          end
        end

        with_credential_concerns(concern) do
          identity = RSB::Auth::Identity.create!
          cred = identity.credentials.create!(
            type: 'RSB::Auth::Credential::EmailPassword',
            identifier: 'sti-helper@example.com',
            password: 'password1234',
            password_confirmation: 'password1234'
          )
          assert_equal 'inherited', cred.sti_helper_test
        end
      end
    end
  end
end
