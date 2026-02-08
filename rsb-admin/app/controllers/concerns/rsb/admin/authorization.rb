module RSB
  module Admin
    module Authorization
      extend ActiveSupport::Concern

      private

      def authorize_admin_action!(resource: nil, action: nil)
        resource ||= controller_name
        action ||= action_name

        unless current_admin_user.can?(resource, action)
          render template: "rsb/admin/shared/forbidden", status: :forbidden
          return
        end
      end
    end
  end
end
