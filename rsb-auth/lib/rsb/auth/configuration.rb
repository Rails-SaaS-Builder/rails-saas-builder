module RSB
  module Auth
    # Configuration for rsb-auth lifecycle handler and model concerns.
    #
    # @example Configure a custom handler and identity concerns
    #   RSB::Auth.configure do |config|
    #     config.lifecycle_handler = "MyApp::AuthLifecycleHandler"
    #     config.identity_concerns << MyApp::HasProfile
    #     config.credential_concerns << MyApp::HasTenant
    #   end
    #
    class Configuration
      # @return [String, nil] fully-qualified class name of the lifecycle handler.
      #   When nil, the base {LifecycleHandler} null object is used.
      attr_accessor :lifecycle_handler

      # @return [Array<Module>] concern modules to include into Identity model.
      #   Applied in order during Rails +to_prepare+ block.
      attr_reader :identity_concerns

      # @return [Array<Module>] concern modules to include into Credential base model.
      #   Applied in order during Rails +to_prepare+ block. Inherited by all STI subtypes.
      attr_reader :credential_concerns

      # @return [Array<Symbol, Hash>] parameters permitted in account update form.
      #   Default: +[:metadata]+. Host app extends this for concern-added nested attributes.
      #
      # @example Permit nested profile attributes
      #   config.permitted_account_params = [:metadata, profile_attributes: [:first_name, :last_name]]
      attr_accessor :permitted_account_params

      def initialize
        @lifecycle_handler = nil
        @identity_concerns = []
        @credential_concerns = []
        @permitted_account_params = [:metadata]
      end

      # Resolves and instantiates the lifecycle handler.
      #
      # If {#lifecycle_handler} is set, constantizes the string and returns a new
      # instance. If nil, returns a base {LifecycleHandler} (null object).
      #
      # The class name is resolved via +constantize+ on every call (not cached),
      # which supports Rails code reloading in development.
      #
      # @return [RSB::Auth::LifecycleHandler] handler instance
      def resolve_lifecycle_handler
        if lifecycle_handler
          lifecycle_handler.constantize.new
        else
          LifecycleHandler.new
        end
      end
    end
  end
end
