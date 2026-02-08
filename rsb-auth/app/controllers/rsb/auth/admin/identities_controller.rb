module RSB
  module Auth
    module Admin
      # Admin controller for managing identity records.
      #
      # This controller provides custom views and actions for the Identity resource
      # in the admin panel, replacing the generic resource views with a curated
      # interface that displays credentials and provides status management actions.
      #
      # @example Accessing the identities index
      #   GET /admin/identities
      #
      # @example Viewing a specific identity
      #   GET /admin/identities/123
      #
      # @example Suspending an identity
      #   PATCH /admin/identities/123/suspend
      class IdentitiesController < RSB::Admin::AdminController
        before_action :authorize_identities
        before_action :set_identity, only: [:show, :suspend, :activate, :deactivate, :revoke_credential, :restore_credential, :restore, :new_credential, :add_credential, :verify_credential, :resend_verification]
        before_action :set_credential, only: [:revoke_credential, :restore_credential, :verify_credential, :resend_verification]

        # Display paginated list of identities with their credentials.
        #
        # Loads identities with their associated credentials to avoid N+1 queries.
        # Results are paginated at 20 per page.
        #
        # @return [void]
        def index
          page = params[:page].to_i
          per_page = 20

          scope = RSB::Auth::Identity.includes(:credentials)

          registration = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
          if registration&.filters&.any? && params[:q].present?
            registration.filters.each do |filter|
              value = params[:q][filter.key.to_s]
              scope = filter.apply(scope, value)
            end
          end

          @identities = scope.order(created_at: :desc)
                             .limit(per_page)
                             .offset(page * per_page)
          @current_page = page
          @per_page = per_page
          @filters = registration&.filters || []
          @filter_values = params[:q]&.to_unsafe_h || {}
        end

        # Display detailed view of a single identity with its credentials.
        #
        # Shows identity information, status, and a table of all associated
        # credentials with their verification and lock status.
        #
        # @return [void]
        def show
          @credentials = @identity.credentials.order(:created_at)
        end

        # Display the new identity creation form.
        #
        # Loads enabled credential types that have an admin_form_partial.
        # The selected type is determined by the ?type= query param, falling
        # back to the first available type.
        #
        # @return [void]
        def new
          @credential_types = admin_credential_types
          @selected_type = params[:type].present? ? RSB::Auth.credentials.find(params[:type].to_sym) : @credential_types.first
          @identity = RSB::Auth::Identity.new
          @credential = @selected_type&.credential_class&.new
        end

        # Create a new identity with its first credential in a single transaction.
        #
        # Creates an Identity (status: active) and a Credential of the selected type.
        # The credential is automatically marked as verified (verified_at set).
        # Both are wrapped in a transaction — if either fails, both roll back.
        #
        # On success: redirects to identity show page with success flash.
        # On failure: re-renders new form with error messages.
        #
        # @return [void]
        def create
          @credential_types = admin_credential_types
          credential_def = RSB::Auth.credentials.find(params[:credential_type]&.to_sym)

          unless credential_def&.admin_form_partial
            redirect_to identity_index_path, alert: "Invalid credential type."
            return
          end

          @selected_type = credential_def

          ActiveRecord::Base.transaction do
            @identity = RSB::Auth::Identity.new(status: "active")
            @credential = credential_def.credential_class.new(
              identity: @identity,
              identifier: params[:identifier],
              password: params[:password],
              password_confirmation: params[:password_confirmation],
              verified_at: Time.current
            )

            @identity.save!
            @credential.save!
          end

          redirect_to identity_show_path, notice: I18n.t("rsb.auth.admin.identities.created")
        rescue ActiveRecord::RecordInvalid
          render :new, status: :unprocessable_entity
        end

        # Display the add credential form for an existing identity.
        #
        # Filters out credential types the identity already has an active credential for.
        # Redirects back if the identity is not in active status.
        #
        # @return [void]
        def new_credential
          unless @identity.active?
            redirect_to identity_show_path, alert: I18n.t("rsb.auth.admin.identities.identity_not_active")
            return
          end

          @credential_types = available_credential_types
          @selected_type = if params[:type].present?
            RSB::Auth.credentials.find(params[:type].to_sym)
          else
            @credential_types.first
          end
          @credential = @selected_type&.credential_class&.new
        end

        # Create a new credential for an existing identity.
        #
        # The credential is automatically marked as verified (verified_at set).
        # Redirects back if the identity is not in active status.
        #
        # @return [void]
        def add_credential
          unless @identity.active?
            redirect_to identity_show_path, alert: I18n.t("rsb.auth.admin.identities.identity_not_active")
            return
          end

          credential_def = RSB::Auth.credentials.find(params[:credential_type]&.to_sym)

          unless credential_def&.admin_form_partial
            redirect_to identity_show_path, alert: I18n.t("rsb.auth.admin.identities.invalid_credential_type")
            return
          end

          @selected_type = credential_def
          @credential = credential_def.credential_class.new(
            identity: @identity,
            identifier: params[:identifier],
            password: params[:password],
            password_confirmation: params[:password_confirmation],
            verified_at: Time.current
          )

          if @credential.save
            redirect_to identity_show_path, notice: I18n.t("rsb.auth.admin.identities.credential_added")
          else
            @credential_types = available_credential_types
            render :new_credential, status: :unprocessable_entity
          end
        end

        # Suspend an identity, preventing the user from accessing the system.
        #
        # Changes the identity status to "suspended". If the identity is already
        # suspended, redirects back with an alert message.
        #
        # @return [void]
        def suspend
          if @identity.suspended?
            redirect_to identity_show_path, alert: "Identity is already suspended."
          else
            @identity.update!(status: "suspended")
            redirect_to identity_show_path, notice: "Identity suspended."
          end
        end

        # Activate an identity, allowing the user to access the system.
        #
        # Changes the identity status to "active". If the identity is already
        # active, redirects back with an alert message.
        #
        # @return [void]
        def activate
          if @identity.active?
            redirect_to identity_show_path, alert: "Identity is already active."
          else
            @identity.update!(status: "active")
            redirect_to identity_show_path, notice: "Identity activated."
          end
        end

        # Deactivate an identity, typically as a permanent action.
        #
        # Changes the identity status to "deactivated". If the identity is already
        # deactivated, redirects back with an alert message.
        #
        # @return [void]
        def deactivate
          if @identity.deactivated?
            redirect_to identity_show_path, alert: "Identity is already deactivated."
          else
            @identity.update!(status: "deactivated")
            redirect_to identity_show_path, notice: "Identity deactivated."
          end
        end

        # Restore a soft-deleted identity, allowing admin account recovery.
        #
        # Changes the identity status from "deleted" back to "active" and clears
        # the deleted_at timestamp. Does NOT restore revoked credentials — admin
        # handles those individually via the existing revoke/restore credential flow.
        #
        # Delegates to AccountService#restore_account for the actual state change
        # and lifecycle hook firing.
        #
        # @return [void]
        def restore
          unless @identity.deleted?
            redirect_to identity_show_path, alert: "Identity is not in deleted status."
            return
          end

          result = RSB::Auth::AccountService.new.restore_account(identity: @identity)
          if result.success?
            redirect_to identity_show_path, notice: "Identity restored."
          else
            redirect_to identity_show_path, alert: result.errors.join(", ")
          end
        end

        # Revoke a specific credential, preventing it from being used for authentication.
        #
        # The credential remains in the database for audit purposes (soft-delete).
        # Fires the after_credential_revoked lifecycle handler hook.
        #
        # @return [void]
        def revoke_credential
          if @credential.revoked?
            redirect_to identity_show_path, alert: "Credential is already revoked."
          else
            @credential.revoke!
            redirect_to identity_show_path, notice: I18n.t("rsb.auth.credentials.revoked_notice")
          end
        end

        # Restore a previously revoked credential.
        #
        # Checks for uniqueness conflicts before restoring: if another active credential
        # with the same type and identifier exists, redirects with an error message.
        #
        # @return [void]
        def restore_credential
          @credential.restore!
          redirect_to identity_show_path, notice: I18n.t("rsb.auth.credentials.restored_notice")
        rescue RSB::Auth::CredentialConflictError
          redirect_to identity_show_path, alert: I18n.t("rsb.auth.credentials.restore_conflict")
        end

        # Manually verify an unverified credential.
        #
        # Sets verified_at and clears the verification token. Uses the model's
        # verify! method which handles both fields atomically.
        #
        # Guards: credential must be active (not revoked) and unverified.
        #
        # @return [void]
        def verify_credential
          if @credential.revoked?
            redirect_to identity_show_path, alert: I18n.t("rsb.auth.credentials.revoked")
            return
          end

          if @credential.verified?
            redirect_to identity_show_path, alert: I18n.t("rsb.auth.admin.identities.already_verified")
            return
          end

          @credential.verify!
          redirect_to identity_show_path, notice: I18n.t("rsb.auth.admin.identities.credential_verified")
        end

        # Resend the verification email for an unverified email-type credential.
        #
        # Guards:
        # - Credential must be active (not revoked) and unverified
        # - Credential must be an EmailPassword type
        # - Rate limited: verification_sent_at must be nil or > 1 minute ago
        #
        # @return [void]
        def resend_verification
          if @credential.revoked?
            redirect_to identity_show_path, alert: I18n.t("rsb.auth.credentials.revoked")
            return
          end

          if @credential.verified?
            redirect_to identity_show_path, alert: I18n.t("rsb.auth.admin.identities.already_verified")
            return
          end

          unless @credential.is_a?(RSB::Auth::Credential::EmailPassword)
            redirect_to identity_show_path, alert: I18n.t("rsb.auth.admin.identities.invalid_credential_type")
            return
          end

          if @credential.verification_sent_at.present? && @credential.verification_sent_at > 1.minute.ago
            redirect_to identity_show_path, alert: I18n.t("rsb.auth.admin.identities.resend_rate_limited")
            return
          end

          @credential.send_verification!

          redirect_to identity_show_path,
            notice: I18n.t("rsb.auth.admin.identities.verification_sent", identifier: @credential.identifier)
        end

        private

        # Load the identity record from params[:id].
        #
        # @return [void]
        # @raise [ActiveRecord::RecordNotFound] if the identity doesn't exist
        def set_identity
          @identity = RSB::Auth::Identity.find(params[:id])
        end

        # Load the credential record from params[:credential_id].
        # Scopes to the current identity to prevent accessing other identities' credentials.
        #
        # @return [void]
        # @raise [ActiveRecord::RecordNotFound] if the credential doesn't exist or belongs to another identity
        def set_credential
          @credential = @identity.credentials.find(params[:credential_id])
        end

        # Returns enabled credential types that have an admin_form_partial.
        #
        # Types without admin_form_partial are hidden from the admin type selector
        # (code-only types like OAuth that need custom integration).
        #
        # @return [Array<RSB::Auth::CredentialDefinition>]
        def admin_credential_types
          RSB::Auth.credentials.enabled.select(&:admin_form_partial)
        end

        # Returns credential types available for the current identity.
        #
        # Filters to enabled types with admin_form_partial, then excludes types
        # the identity already has an active (non-revoked) credential for.
        #
        # @return [Array<RSB::Auth::CredentialDefinition>]
        def available_credential_types
          existing_types = @identity.active_credentials.pluck(:type).map do |type_class|
            RSB::Auth.credentials.all.find { |d| d.class_name == type_class }&.key
          end.compact

          admin_credential_types.reject { |d| existing_types.include?(d.key) }
        end

        # Path to the identities index page.
        # @return [String]
        def identity_index_path
          "/admin/identities"
        end

        # Get the path to the identity show page.
        #
        # @return [String] the URL path for the current identity's show page
        def identity_show_path
          "/admin/identities/#{@identity.id}"
        end

        # Authorize the current admin user for identity actions.
        #
        # Uses the "identities" resource key (not "rsb_auth_identities") because
        # the engine's isolate_namespace strips the module prefix from route keys.
        #
        # @return [void]
        # @raise [ActionController::Forbidden] if the user lacks permission
        def authorize_identities
          authorize_admin_action!(resource: "identities", action: action_name)
        end
      end
    end
  end
end
