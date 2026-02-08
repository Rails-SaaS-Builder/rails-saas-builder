module RSB
  module Entitlements
    module Admin
      class PaymentRequestsController < RSB::Admin::AdminController
        before_action :authorize_payment_requests
        before_action :set_payment_request, only: [:show, :approve, :reject, :refund]

        def index
          page = params[:page].to_i
          per_page = 20
          scope = RSB::Entitlements::PaymentRequest.order(created_at: :desc)

          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.where(provider_key: params[:provider_key]) if params[:provider_key].present?
          scope = scope.where(requestable_type: params[:requestable_type]) if params[:requestable_type].present?

          @payment_requests = scope.limit(per_page).offset(page * per_page)
          @current_page = page
          @per_page = per_page
        end

        def show
          definition = RSB::Entitlements.providers.find(@payment_request.provider_key)
          if definition
            provider_instance = definition.provider_class.new(@payment_request)
            @provider_details = provider_instance.admin_details
            @provider_definition = definition
          else
            @provider_details = {}
            @provider_definition = nil
          end
        end

        def approve
          definition = RSB::Entitlements.providers.find(@payment_request.provider_key)
          return redirect_with_alert("Provider not found") unless definition

          return redirect_with_alert("Request is not actionable") unless @payment_request.actionable?

          @payment_request.update!(
            resolved_by: current_admin_user.email,
            resolved_at: Time.current
          )

          provider_instance = definition.provider_class.new(@payment_request)
          provider_instance.complete!

          redirect_to "/admin/payment_requests/#{@payment_request.id}",
                      notice: "Payment request approved."
        end

        def reject
          definition = RSB::Entitlements.providers.find(@payment_request.provider_key)
          return redirect_with_alert("Provider not found") unless definition

          return redirect_with_alert("Request is not actionable") unless @payment_request.actionable?

          @payment_request.update!(
            admin_note: params[:admin_note],
            resolved_by: current_admin_user.email,
            resolved_at: Time.current
          )

          provider_instance = definition.provider_class.new(@payment_request)
          provider_instance.reject!

          redirect_to "/admin/payment_requests/#{@payment_request.id}",
                      notice: "Payment request rejected."
        end

        def refund
          definition = RSB::Entitlements.providers.find(@payment_request.provider_key)
          return redirect_with_alert("Provider not found") unless definition
          return redirect_with_alert("Provider does not support refunds") unless definition.refundable
          return redirect_with_alert("Request is not approved") unless @payment_request.approved?

          @payment_request.update!(
            resolved_by: current_admin_user.email,
            resolved_at: Time.current
          )

          provider_instance = definition.provider_class.new(@payment_request)
          provider_instance.refund!

          # Revoke linked entitlement if present
          if @payment_request.entitlement&.active?
            @payment_request.entitlement.revoke!(reason: "refund")
          end

          @payment_request.update!(status: "refunded")

          redirect_to "/admin/payment_requests/#{@payment_request.id}",
                      notice: "Payment request refunded."
        end

        private

        def set_payment_request
          @payment_request = RSB::Entitlements::PaymentRequest.find(params[:id])
        end

        def authorize_payment_requests
          authorize_admin_action!(resource: "payment_requests", action: action_name)
        end

        def redirect_with_alert(message)
          redirect_to "/admin/payment_requests/#{@payment_request.id}", alert: message
        end
      end
    end
  end
end
