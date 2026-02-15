# frozen_string_literal: true

require 'test_helper'

module RSB
  module Entitlements
    class ProviderDefinitionTest < ActiveSupport::TestCase
      setup do
        @provider_class = Class.new(PaymentProvider::Base) do
          def self.provider_key = :test_provider
          def self.provider_label = 'Test Provider'
          def self.manual_resolution? = true
          def self.admin_actions = %i[approve reject]
          def self.refundable? = false

          def initiate! = { instructions: 'Test' }
          def complete!(_params = {}) = nil
          def reject!(_params = {}) = nil
        end
      end

      test 'build_from creates definition from provider class' do
        definition = ProviderDefinition.build_from(@provider_class)

        assert_equal :test_provider, definition.key
        assert_equal 'Test Provider', definition.label
        assert_equal @provider_class, definition.provider_class
        assert_equal true, definition.manual_resolution
        assert_equal %i[approve reject], definition.admin_actions
        assert_equal false, definition.refundable
      end

      test 'build_from raises for non-Base class' do
        assert_raises(ArgumentError) do
          ProviderDefinition.build_from(String)
        end
      end

      test 'definition is a frozen Data object' do
        definition = ProviderDefinition.build_from(@provider_class)
        assert definition.frozen?
      end
    end
  end
end
