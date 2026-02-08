module RSB
  module Auth
    module Admin
      class SessionsManagementController < RSB::Admin::AdminController
        def index
          page = params[:page].to_i
          per_page = 20
          @sessions = RSB::Auth::Session.active
                        .includes(:identity)
                        .order(last_active_at: :desc)
                        .limit(per_page)
                        .offset(page * per_page)
          @current_page = page
          @per_page = per_page
        end

        def destroy
          session_record = RSB::Auth::Session.find(params[:id])
          session_record.revoke!
          redirect_to "/admin/sessions_management", notice: "Session revoked."
        end
      end
    end
  end
end
