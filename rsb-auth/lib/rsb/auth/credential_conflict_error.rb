# frozen_string_literal: true

module RSB
  module Auth
    # Raised when restoring a revoked credential would violate the active
    # uniqueness constraint (another active credential has the same type + identifier).
    #
    # @example Handling the error
    #   begin
    #     credential.restore!
    #   rescue RSB::Auth::CredentialConflictError => e
    #     e.message # => "Cannot restore — another active credential with the same identifier exists."
    #   end
    #
    class CredentialConflictError < StandardError
      def initialize(msg = 'Cannot restore — another active credential with the same identifier exists.')
        super
      end
    end
  end
end
