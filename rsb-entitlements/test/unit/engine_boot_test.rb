# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class EngineBootTest < ActiveSupport::TestCase
      test 'top-level module no longer exposes v0 surface' do
        refute RSB::Entitlements.respond_to?(:providers)
        refute defined?(RSB::Entitlements::PaymentProvider),
               'rsb-entitlements must not define PaymentProvider (compat shim removed in Task 17)'
        refute defined?(RSB::Entitlements::PaymentRequest)
        refute defined?(RSB::Entitlements::Entitlement)
        refute defined?(RSB::Entitlements::ProviderRegistry)
        refute defined?(RSB::Entitlements::ProviderDefinition)
        refute defined?(RSB::Entitlements::UsageCounterService)
      end

      test 'rsb_entitlements.ready initializer is gone' do
        names = Rails.application.initializers.map(&:name)
        refute_includes names, 'rsb_entitlements.ready'
      end

      test 'expected v1 initializers are present' do
        names = Rails.application.initializers.map(&:name)
        %w[
          rsb_entitlements.exclude_admin_controllers
          rsb_entitlements.register_settings
          rsb_entitlements.i18n
          rsb_entitlements.admin_hooks
        ].each { |n| assert_includes names, n }
      end
    end
  end
end
