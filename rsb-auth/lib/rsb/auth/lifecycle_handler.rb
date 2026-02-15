# frozen_string_literal: true

module RSB
  module Auth
    # Base lifecycle handler for auth events. All methods are no-ops by default.
    # Subclass and override specific methods to hook into auth lifecycle events.
    #
    # Handler instances are stateless — a new instance is created for each invocation.
    # Do not store instance state between calls.
    #
    # Exceptions in handler methods propagate to the caller. The handler is
    # responsible for its own error handling.
    #
    # @example Subclassing in host app
    #   class MyAuthLifecycle < RSB::Auth::LifecycleHandler
    #     def after_identity_created(identity)
    #       AuditLog.record(:identity_created, identity_id: identity.id)
    #     end
    #   end
    #
    class LifecycleHandler
      # Called after a new identity is committed to the database.
      #
      # @param identity [RSB::Auth::Identity] the newly created identity
      # @return [void]
      def after_identity_created(identity); end

      # Called after a new session is committed to the database.
      #
      # @param session [RSB::Auth::Session] the newly created session
      # @return [void]
      def after_session_created(session); end

      # Called when a credential is locked due to exceeding the failed attempts threshold.
      #
      # @param credential [RSB::Auth::Credential] the locked credential
      # @return [void]
      def after_credential_locked(credential); end

      # Called after a credential is verified (email confirmation, etc.).
      #
      # @param identity [RSB::Auth::Identity] the identity whose credential was verified
      # @return [void]
      def after_identity_verified(identity); end

      # Called after a credential is revoked (soft-deleted).
      #
      # @param credential [RSB::Auth::Credential] the revoked credential
      # @return [void]
      def after_credential_revoked(credential); end

      # Called after a revoked credential is restored.
      #
      # @param credential [RSB::Auth::Credential] the restored credential
      # @return [void]
      def after_credential_restored(credential); end

      # Called after an identity is soft-deleted by the user.
      #
      # @param identity [RSB::Auth::Identity] the deleted identity
      # @return [void]
      def after_identity_deleted(identity); end

      # Called after a deleted identity is restored by an admin.
      #
      # @param identity [RSB::Auth::Identity] the restored identity
      # @return [void]
      def after_identity_restored(identity); end
    end
  end
end
