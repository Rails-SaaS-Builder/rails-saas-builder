module RSB
  module Auth
    # Service for account management operations: updating identity data
    # and changing passwords.
    #
    # @example Update identity metadata
    #   result = AccountService.new.update(identity: identity, params: { metadata: { "name" => "Alice" } })
    #   result.success? # => true
    #
    # @example Change password
    #   result = AccountService.new.change_password(
    #     credential: credential,
    #     current_password: "old",
    #     new_password: "new12345",
    #     new_password_confirmation: "new12345",
    #     current_session: session
    #   )
    #   result.success? # => true
    #
    class AccountService
      UpdateResult = Data.define(:success?, :identity, :errors)
      PasswordResult = Data.define(:success?, :errors)
      DeletionResult = Data.define(:success?, :errors)
      RestoreResult = Data.define(:success?, :identity, :errors)

      # Updates identity attributes (metadata or concern-provided nested attributes).
      # Handles validation failures and invalid enum/argument errors (e.g. invalid status).
      #
      # @param identity [RSB::Auth::Identity] the identity to update
      # @param params [Hash] permitted attributes to update
      # @return [UpdateResult] result with success status, identity, and errors (if any)
      def update(identity:, params:)
        if identity.update(params)
          UpdateResult.new(success?: true, identity: identity, errors: [])
        else
          UpdateResult.new(success?: false, identity: identity, errors: identity.errors.full_messages)
        end
      rescue ArgumentError => e
        UpdateResult.new(success?: false, identity: identity, errors: [e.message])
      end

      # Changes the password on a credential after verifying the current password.
      # Revokes all other active sessions for the identity (security best practice).
      #
      # @param credential [RSB::Auth::Credential] the credential to update
      # @param current_password [String] the user's current password for verification
      # @param new_password [String] the new password
      # @param new_password_confirmation [String] confirmation of the new password
      # @param current_session [RSB::Auth::Session] the session to keep active
      # @return [PasswordResult] result with success status and errors
      def change_password(credential:, current_password:, new_password:, new_password_confirmation:, current_session:)
        unless credential.authenticate(current_password)
          return PasswordResult.new(success?: false, errors: ["Current password is incorrect."])
        end

        credential.password = new_password
        credential.password_confirmation = new_password_confirmation

        if credential.save
          credential.identity.sessions.active
            .where.not(id: current_session.id)
            .update_all(expires_at: Time.current)
          PasswordResult.new(success?: true, errors: [])
        else
          PasswordResult.new(success?: false, errors: credential.errors.full_messages)
        end
      end

      # Soft-deletes an identity after verifying the user's password.
      #
      # Finds the identity's primary credential and authenticates with the given
      # password. On success, wraps all state changes in a transaction:
      # revokes all active sessions, revokes all active credentials, and sets
      # the identity status to +deleted+ with +deleted_at+ timestamp.
      #
      # The +after_identity_deleted+ lifecycle hook fires after the transaction
      # commits.
      #
      # @param identity [RSB::Auth::Identity] the identity to delete
      # @param password [String] the user's current password for confirmation
      # @param current_session [RSB::Auth::Session] the user's current session (included in revocation)
      # @return [DeletionResult] result with success status and errors
      def delete_account(identity:, password:, current_session:)
        primary = identity.primary_credential

        unless primary
          return DeletionResult.new(
            success?: false,
            errors: ["No active login method found. Contact support to delete your account."]
          )
        end

        unless primary.authenticate(password)
          return DeletionResult.new(
            success?: false,
            errors: ["Current password is incorrect."]
          )
        end

        ActiveRecord::Base.transaction do
          identity.sessions.active.update_all(expires_at: Time.current)
          identity.active_credentials.each(&:revoke!)
          identity.update!(status: "deleted", deleted_at: Time.current)
        end

        RSB::Auth.configuration.resolve_lifecycle_handler.after_identity_deleted(identity)
        DeletionResult.new(success?: true, errors: [])
      rescue ActiveRecord::ActiveRecordError => e
        DeletionResult.new(success?: false, errors: [e.message])
      end

      # Restores a soft-deleted identity to active status.
      #
      # Only identities with +deleted+ status can be restored. Sets status to
      # +active+ and clears +deleted_at+. Does NOT restore revoked credentials —
      # those must be restored individually by an admin via the existing
      # credential restore flow.
      #
      # The +after_identity_restored+ lifecycle hook fires after the update.
      #
      # @param identity [RSB::Auth::Identity] the identity to restore
      # @return [RestoreResult] result with success status, identity, and errors
      def restore_account(identity:)
        unless identity.deleted?
          return RestoreResult.new(
            success?: false,
            identity: identity,
            errors: ["Identity is not in deleted status."]
          )
        end

        identity.update!(status: "active", deleted_at: nil)
        RSB::Auth.configuration.resolve_lifecycle_handler.after_identity_restored(identity)
        RestoreResult.new(success?: true, identity: identity, errors: [])
      end
    end
  end
end
