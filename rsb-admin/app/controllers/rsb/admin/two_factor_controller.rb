# frozen_string_literal: true

module RSB
  module Admin
    # Handles TOTP 2FA enrollment, backup codes display, and disable.
    # All actions require admin authentication (inherited from AdminController).
    class TwoFactorController < AdminController
      skip_before_action :enforce_two_factor_enrollment

      # GET /admin/profile/two_factor/new
      # Renders the enrollment page with QR code and manual entry key.
      def new
        @admin_user = current_admin_user
        @otp_secret = @admin_user.generate_otp_secret!
        session[:rsb_admin_otp_provisional_secret] = @otp_secret

        issuer = RSB::Settings.get("admin.app_name") rescue "RSB Admin"
        @otp_uri = @admin_user.otp_provisioning_uri(@otp_secret, issuer: issuer)
        @qr_svg = RQRCode::QRCode.new(@otp_uri).as_svg(
          module_size: 4,
          standalone: true,
          use_path: true
        )
      end

      # POST /admin/profile/two_factor
      # Confirms enrollment by verifying the TOTP code against the provisional secret.
      def create
        @admin_user = current_admin_user
        @otp_secret = session[:rsb_admin_otp_provisional_secret]

        unless @otp_secret
          redirect_to rsb_admin.new_profile_two_factor_path, alert: "Enrollment session expired. Please try again."
          return
        end

        totp = ROTP::TOTP.new(@otp_secret)
        if totp.verify(params[:otp_code].to_s, drift_behind: 30, drift_ahead: 30)
          # Persist OTP secret and enable 2FA
          @admin_user.update!(otp_secret: @otp_secret, otp_required: true)

          # Generate backup codes
          codes = @admin_user.generate_backup_codes!
          session[:rsb_admin_backup_codes] = codes
          session.delete(:rsb_admin_otp_provisional_secret)
          session.delete(:rsb_admin_force_2fa_enrollment)

          redirect_to rsb_admin.profile_two_factor_backup_codes_path
        else
          # Re-render enrollment page with error
          issuer = RSB::Settings.get("admin.app_name") rescue "RSB Admin"
          @otp_uri = @admin_user.otp_provisioning_uri(@otp_secret, issuer: issuer)
          @qr_svg = RQRCode::QRCode.new(@otp_uri).as_svg(
            module_size: 4,
            standalone: true,
            use_path: true
          )
          flash.now[:alert] = "Invalid verification code. Please try again."
          render :new, status: :unprocessable_entity
        end
      end

      # GET /admin/profile/two_factor/backup_codes
      # Displays backup codes one time after enrollment.
      def backup_codes
        @backup_codes = session.delete(:rsb_admin_backup_codes)
        unless @backup_codes
          redirect_to rsb_admin.profile_path, alert: "Backup codes are only shown once after enrollment."
          return
        end
      end

      # DELETE /admin/profile/two_factor
      # Disables 2FA with current password confirmation.
      def destroy
        admin = current_admin_user

        unless admin.authenticate(params[:current_password].to_s)
          redirect_to rsb_admin.profile_path, alert: "Incorrect password."
          return
        end

        admin.disable_otp!
        redirect_to rsb_admin.profile_path, notice: "Two-factor authentication disabled."
      end

      private

      # Override breadcrumbs for 2FA pages
      def build_breadcrumbs
        super
        add_breadcrumb(I18n.t("rsb.admin.profile.title", default: "Profile"), rsb_admin.profile_path)
        add_breadcrumb("Two-Factor Authentication")
      end
    end
  end
end
