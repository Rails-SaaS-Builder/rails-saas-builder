module RSB
  module Entitlements
    module PaymentProvider
      # Abstract base class for payment providers.
      #
      # Subclasses MUST override these class methods:
      #   - self.provider_key -> Symbol
      #   - self.provider_label -> String
      #
      # Subclasses MUST override these instance methods:
      #   - initiate! -> Hash
      #   - complete!(params) -> void
      #   - reject!(params) -> void
      #
      # Subclasses MAY override:
      #   - self.manual_resolution? -> Boolean (default: false)
      #   - self.admin_actions -> Array<Symbol> (default: [])
      #   - self.refundable? -> Boolean (default: false)
      #   - self.required_settings -> Array<Symbol> (default: [])
      #   - refund!(params) -> void (default: raises NotImplementedError)
      #   - admin_details -> Hash (default: {})
      #
      # @example Defining a provider
      #   class MyProvider < RSB::Entitlements::PaymentProvider::Base
      #     def self.provider_key = :my_provider
      #     def self.provider_label = "My Provider"
      #
      #     settings_schema do
      #       setting :api_key, type: :string, default: ""
      #     end
      #
      #     def initiate!
      #       { redirect_url: "https://..." }
      #     end
      #
      #     def complete!(params = {})
      #       # finalize payment
      #     end
      #
      #     def reject!(params = {})
      #       # handle rejection
      #     end
      #   end
      class Base
        attr_reader :payment_request

        # @param payment_request [RSB::Entitlements::PaymentRequest]
        def initialize(payment_request)
          @payment_request = payment_request
        end

        # --- Class methods (override in subclass) ---

        # @return [Symbol] unique provider key
        def self.provider_key
          raise NotImplementedError, "#{name} must implement self.provider_key"
        end

        # @return [String] human-readable label
        def self.provider_label
          raise NotImplementedError, "#{name} must implement self.provider_label"
        end

        # @return [Boolean] whether admin must manually approve/reject
        def self.manual_resolution?
          false
        end

        # @return [Array<Symbol>] actions admin can take (e.g., [:approve, :reject])
        def self.admin_actions
          []
        end

        # @return [Boolean] whether approved requests can be refunded
        def self.refundable?
          false
        end

        # @return [Array<Symbol>] settings keys that must have non-default values at registration
        def self.required_settings
          []
        end

        # Declare provider-specific settings schema.
        # The block receives the RSB::Settings::Schema DSL.
        # An `enabled` setting is auto-added by the registry.
        #
        # @example
        #   settings_schema do
        #     setting :api_key, type: :string, default: ""
        #   end
        def self.settings_schema(&block)
          if block_given?
            @settings_schema_block = block
          else
            @settings_schema_block
          end
        end

        # --- Instance methods (override in subclass) ---

        # Start the payment flow. Called after PaymentRequest creation.
        #
        # @return [Hash] one of:
        #   - { redirect_url: "..." } for redirect-based flows
        #   - { instructions: "..." } for instruction-based flows
        #   - { status: :completed } for instant flows
        def initiate!
          raise NotImplementedError, "#{self.class.name} must implement #initiate!"
        end

        # Finalize a successful payment. Called on admin approval or webhook confirmation.
        #
        # @param params [Hash] provider-specific completion params
        # @return [void]
        def complete!(params = {})
          raise NotImplementedError, "#{self.class.name} must implement #complete!"
        end

        # Reject a payment. Called on admin rejection.
        #
        # @param params [Hash] provider-specific rejection params
        # @return [void]
        def reject!(params = {})
          raise NotImplementedError, "#{self.class.name} must implement #reject!"
        end

        # Refund an approved payment. Only called if refundable? is true.
        #
        # @param params [Hash] provider-specific refund params
        # @return [void]
        # @raise [NotImplementedError] if provider does not support refunds
        def refund!(params = {})
          raise NotImplementedError, "#{self.class.name} does not support refunds"
        end

        # Provider-specific details for the admin show page.
        #
        # @return [Hash] { "Label" => "value", ... }
        def admin_details
          {}
        end
      end
    end
  end
end
