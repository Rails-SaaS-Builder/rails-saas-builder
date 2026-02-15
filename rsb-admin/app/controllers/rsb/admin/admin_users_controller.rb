# frozen_string_literal: true

module RSB
  module Admin
    # Handles CRUD operations for admin user accounts.
    # Provides listing, viewing, creating, editing, updating,
    # and deleting admin users, with self-deletion protection.
    class AdminUsersController < AdminController
      before_action :authorize_admin_users
      before_action :set_admin_user, only: %i[show edit update destroy]

      # GET /admin/admin_users
      # Lists all admin users ordered by email, eagerly loading roles.
      def index
        @rsb_page_title = I18n.t('rsb.admin.admin_users.index.page_title', default: 'Admin Users')
        @admin_users = AdminUser.includes(:role).order(:email)
      end

      # GET /admin/admin_users/:id
      # Displays details for a single admin user.
      def show; end

      # GET /admin/admin_users/new
      # Renders the form for creating a new admin user.
      def new
        @admin_user = AdminUser.new
      end

      # POST /admin/admin_users
      # Creates a new admin user with the given params.
      # Redirects to show on success, re-renders form on failure.
      def create
        @admin_user = AdminUser.new(admin_user_params)
        if @admin_user.save
          redirect_to rsb_admin.admin_user_path(@admin_user), notice: 'Admin user created.'
        else
          render :new, status: :unprocessable_entity
        end
      end

      # GET /admin/admin_users/:id/edit
      # Renders the edit form for an existing admin user.
      def edit; end

      # PATCH /admin/admin_users/:id
      # Updates an existing admin user.
      # Blank password fields are stripped so the existing password is not cleared.
      def update
        update_params = admin_user_params
        if update_params[:password].blank?
          update_params.delete(:password)
          update_params.delete(:password_confirmation)
        end

        if @admin_user.update(update_params)
          redirect_to rsb_admin.admin_user_path(@admin_user), notice: 'Admin user updated.'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      # DELETE /admin/admin_users/:id
      # Deletes an admin user. Self-deletion is prevented.
      def destroy
        if @admin_user == current_admin_user
          redirect_to rsb_admin.admin_users_path, alert: 'You cannot delete your own account.'
          return
        end

        @admin_user.destroy!
        redirect_to rsb_admin.admin_users_path, notice: 'Admin user deleted.'
      end

      private

      # Builds breadcrumbs for admin user pages.
      # Dashboard > System > Admin Users > #ID (if applicable) > New/Edit
      #
      # @return [void]
      def build_breadcrumbs
        super
        add_breadcrumb(I18n.t('rsb.admin.shared.system'))
        add_breadcrumb(I18n.t('rsb.admin.admin_users.title'), rsb_admin.admin_users_path)
        add_breadcrumb("##{params[:id]}", rsb_admin.admin_user_path(params[:id])) if params[:id].present?
        add_breadcrumb(I18n.t('rsb.admin.shared.new', resource: 'Admin User')) if action_name.in?(%w[new create])
        return unless action_name.in?(%w[edit update])

        add_breadcrumb(I18n.t('rsb.admin.shared.edit'))
      end

      # Finds the admin user by ID from the URL params.
      # @return [void]
      def set_admin_user
        @admin_user = AdminUser.find(params[:id])
      end

      # Permits the allowed admin user params from the request.
      # @return [ActionController::Parameters]
      def admin_user_params
        params.require(:admin_user).permit(:email, :password, :password_confirmation, :role_id)
      end

      # Authorizes the current admin user for admin_users actions.
      # @return [void]
      def authorize_admin_users
        authorize_admin_action!(resource: 'admin_users', action: action_name)
      end
    end
  end
end
