# frozen_string_literal: true

module RSB
  module Entitlements
    # Immutable data object representing a registered payment provider.
    # Built from a PaymentProvider::Base subclass via .build_from.
    #
    # @example
    #   definition = ProviderDefinition.build_from(MyProvider)
    #   definition.key            # => :my_provider
    #   definition.label          # => "My Provider"
    #   definition.provider_class # => MyProvider
    ProviderDefinition = Data.define(
      :key,               # Symbol — unique provider key
      :label,             # String — human-readable label
      :provider_class,    # Class — the PaymentProvider::Base subclass
      :manual_resolution, # Boolean — whether admin must approve/reject
      :admin_actions,     # Array<Symbol> — actions admin can take
      :refundable         # Boolean — whether refunds are supported
    ) do
      # Build a ProviderDefinition from a PaymentProvider::Base subclass.
      #
      # @param klass [Class] a class inheriting from PaymentProvider::Base
      # @return [ProviderDefinition]
      # @raise [ArgumentError] if klass does not inherit from Base
      def self.build_from(klass)
        unless klass < PaymentProvider::Base
          raise ArgumentError,
                "#{klass} must inherit from RSB::Entitlements::PaymentProvider::Base"
        end

        new(
          key: klass.provider_key,
          label: klass.provider_label,
          provider_class: klass,
          manual_resolution: klass.manual_resolution?,
          admin_actions: klass.admin_actions,
          refundable: klass.refundable?
        )
      end
    end
  end
end
