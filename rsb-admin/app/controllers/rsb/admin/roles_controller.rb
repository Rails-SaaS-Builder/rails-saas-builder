module RSB
  module Admin
    class RolesController < AdminController
      before_action :authorize_roles
      before_action :set_role, only: [:show, :edit, :update, :destroy]

      def index
        @rsb_page_title = I18n.t("rsb.admin.roles.index.page_title", default: "Roles")
        @roles = Role.all.order(:name)
      end

      def show
        @registry = RSB::Admin.registry
      end

      def new
        @role = Role.new(permissions: {})
        @registry = RSB::Admin.registry
      end

      def create
        @role = Role.new(role_params)
        @registry = RSB::Admin.registry
        if @role.save
          redirect_to rsb_admin.role_path(@role), notice: "Role created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @registry = RSB::Admin.registry
      end

      def update
        @registry = RSB::Admin.registry
        if @role.update(role_params)
          redirect_to rsb_admin.role_path(@role), notice: "Role updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @role.destroy
          redirect_to rsb_admin.roles_path, notice: "Role deleted."
        else
          redirect_to rsb_admin.roles_path, alert: "Cannot delete role: #{@role.errors.full_messages.join(', ')}"
        end
      end

      private

      # Builds breadcrumbs for role management pages.
      # Dashboard > System > Roles > #ID (if applicable) > New/Edit
      #
      # @return [void]
      def build_breadcrumbs
        super
        add_breadcrumb(I18n.t("rsb.admin.shared.system"))
        add_breadcrumb(I18n.t("rsb.admin.roles.title"), rsb_admin.roles_path)
        if params[:id].present?
          add_breadcrumb("##{params[:id]}", rsb_admin.role_path(params[:id]))
        end
        if action_name.in?(%w[new create])
          add_breadcrumb(I18n.t("rsb.admin.shared.new", resource: "Role"))
        end
        if action_name.in?(%w[edit update])
          add_breadcrumb(I18n.t("rsb.admin.shared.edit"))
        end
      end

      def set_role
        @role = Role.find(params[:id])
      end

      def role_params
        permitted = params.require(:role).permit(
          :name,
          :permissions_json,
          :superadmin_toggle,
          permissions_checkboxes: {}
        )

        # Rails strong params cannot cleanly permit a hash-of-arrays,
        # so we manually extract permissions_checkboxes
        if params[:role][:permissions_checkboxes].present?
          permitted[:permissions_checkboxes] = params[:role][:permissions_checkboxes]
            .to_unsafe_h
            .transform_values { |v| Array(v) }
        end

        permitted
      end

      def authorize_roles
        authorize_admin_action!(resource: "roles", action: action_name)
      end
    end
  end
end
