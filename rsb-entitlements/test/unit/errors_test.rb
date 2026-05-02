# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class ErrorsTest < ActiveSupport::TestCase
      test 'HardDeleteForbidden is defined under RSB::Entitlements' do
        assert defined?(RSB::Entitlements::HardDeleteForbidden),
               'expected RSB::Entitlements::HardDeleteForbidden to be defined'
      end

      test 'HardDeleteForbidden inherits from StandardError' do
        assert_operator RSB::Entitlements::HardDeleteForbidden, :<, StandardError
      end

      test 'OverLimit is defined under RSB::Entitlements' do
        assert defined?(RSB::Entitlements::OverLimit),
               'expected RSB::Entitlements::OverLimit to be defined'
      end

      test 'OverLimit inherits from StandardError' do
        assert_operator RSB::Entitlements::OverLimit, :<, StandardError
      end

      test 'CannotRelease is defined under RSB::Entitlements' do
        assert defined?(RSB::Entitlements::CannotRelease),
               'expected RSB::Entitlements::CannotRelease to be defined'
      end

      test 'CannotRelease inherits from StandardError' do
        assert_operator RSB::Entitlements::CannotRelease, :<, StandardError
      end

      test 'errors are raisable with a message' do
        err = assert_raises(RSB::Entitlements::OverLimit) do
          raise RSB::Entitlements::OverLimit, 'no capacity'
        end
        assert_equal 'no capacity', err.message
      end

      test 'HardDeleteForbidden is raisable without a message' do
        assert_raises(RSB::Entitlements::HardDeleteForbidden) do
          raise RSB::Entitlements::HardDeleteForbidden
        end
      end
    end
  end
end
