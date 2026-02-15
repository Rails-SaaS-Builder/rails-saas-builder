# frozen_string_literal: true

module RSB
  module Admin
    # Handles the admin user profile page where authenticated admins
    # can view and edit their own email and password.
    #
    # Unlike other admin controllers, ProfileController does NOT perform
    # RBAC authorization — any authenticated admin can access their profile.
    # This is intentional: even admins with no role can change their
    # credentials and sign out.
    class ProfileController < AdminController
      skip_before_action :require_admin_authentication, only: [:verify_email]
      skip_before_action :build_breadcrumbs, only: [:verify_email]
      skip_before_action :track_session_activity, only: [:verify_email]
      # GET /admin/profile
      # Displays the current admin user's profile information.
      #
      # @return [void]
      def show
        @rsb_page_title = I18n.t('rsb.admin.profile.show.page_title', default: 'Profile')
        @admin_user = current_admin_user
      end

      # GET /admin/profile/edit
      # Renders the profile edit form for email and password changes.
      #
      # @return [void]
      def edit
        @rsb_page_title = I18n.t('rsb.admin.profile.edit.page_title', default: 'Edit Profile')
        @admin_user = current_admin_user
      end

      # PATCH /admin/profile
      # Updates the current admin user's email and/or password.
      # Requires current password confirmation for all changes.
      #
      # Email changes: stores new email as pending_email and sends verification.
      # Password changes: updates immediately and destroys other sessions.
      # If email unchanged: only password is updated (if provided).
      #
      # @return [void]
      def update
        @admin_user = current_admin_user

        unless @admin_user.authenticate(params[:current_password].to_s)
          flash.now[:alert] = I18n.t('rsb.admin.profile.password_incorrect')
          render :edit, status: :unprocessable_entity
          return
        end

        new_email = params[:admin_user][:email]&.strip&.downcase
        email_changed = new_email.present? && new_email != @admin_user.email

        # Handle password update
        password_params = {}
        if params[:admin_user][:password].present?
          password_params[:password] = params[:admin_user][:password]
          password_params[:password_confirmation] = params[:admin_user][:password_confirmation]
        end

        if password_params.any?
          unless @admin_user.update(password_params)
            render :edit, status: :unprocessable_entity
            return
          end
          # Revoke all other sessions on password change (rule #15)
          @admin_user.admin_sessions.where.not(session_token: session[:rsb_admin_session_token]).destroy_all
        end

        # Handle email change — initiate verification
        if email_changed
          begin
            @admin_user.generate_email_verification!(new_email)
            AdminMailer.email_verification(@admin_user).deliver_later
            redirect_to rsb_admin.profile_path, notice: I18n.t('rsb.admin.profile.verification_sent')
          rescue ActiveRecord::RecordInvalid
            render :edit, status: :unprocessable_entity
          end
        else
          redirect_to rsb_admin.profile_path, notice: I18n.t('rsb.admin.profile.updated')
        end
      end

      # GET /admin/profile/verify_email?token=...
      # Confirms a pending email change if the token is valid and not expired.
      # Does not require authentication — the token itself is the proof.
      #
      # @return [void]
      def verify_email
        admin = AdminUser.find_by(email_verification_token: params[:token])

        if admin.nil?
          redirect_to rsb_admin.login_path, alert: I18n.t('rsb.admin.profile.verification_invalid')
          return
        end

        if admin.email_verification_expired?
          redirect_to rsb_admin.profile_path, alert: I18n.t('rsb.admin.profile.verification_expired')
          return
        end

        admin.verify_email!
        redirect_to rsb_admin.profile_path, notice: I18n.t('rsb.admin.profile.email_verified')
      end

      # POST /admin/profile/resend_verification
      # Regenerates verification token and resends the verification email.
      #
      # @return [void]
      def resend_verification
        @admin_user = current_admin_user

        if @admin_user.email_verification_pending?
          @admin_user.generate_email_verification!(@admin_user.pending_email)
          AdminMailer.email_verification(@admin_user).deliver_later
          redirect_to rsb_admin.profile_path, notice: I18n.t('rsb.admin.profile.verification_resent')
        else
          redirect_to rsb_admin.profile_path
        end
      end

      private

      # Builds breadcrumbs for profile pages.
      # Admin > Profile (show) or Admin > Profile > Edit (edit/update)
      #
      # @return [void]
      def build_breadcrumbs
        super
        add_breadcrumb(I18n.t('rsb.admin.profile.title'), rsb_admin.profile_path)
        return unless action_name.in?(%w[edit update])

        add_breadcrumb(I18n.t('rsb.admin.shared.edit'))
      end

      # Permits the allowed profile params from the request.
      # Note: role_id is NOT permitted — admins cannot change their own role.
      #
      # @return [ActionController::Parameters]
      def profile_params
        params.require(:admin_user).permit(:email, :password, :password_confirmation)
      end
    end
  end
end
