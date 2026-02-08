module RSB
  module Entitlements
    module Admin
      class PlansController < RSB::Admin::AdminController
        before_action :authorize_plans
        before_action :set_plan, only: [:show, :edit, :update, :destroy]

        def index
          page = params[:page].to_i
          per_page = 20
          @plans = RSB::Entitlements::Plan.order(:created_at)
                     .limit(per_page)
                     .offset(page * per_page)
          @current_page = page
          @per_page = per_page
        end

        def show; end

        def new
          @plan = RSB::Entitlements::Plan.new(
            features: {},
            limits: {},
            metadata: {},
            active: true
          )
        end

        def create
          @plan = RSB::Entitlements::Plan.new(plan_params)
          if @plan.save
            redirect_to "/admin/plans/#{@plan.id}", notice: "Plan created."
          else
            render :new, status: :unprocessable_entity
          end
        end

        def edit; end

        def update
          if @plan.update(plan_params)
            redirect_to "/admin/plans/#{@plan.id}", notice: "Plan updated."
          else
            render :edit, status: :unprocessable_entity
          end
        end

        def destroy
          if @plan.entitlements.exists?
            redirect_to "/admin/plans",
                        alert: "Cannot delete a plan with active entitlements."
          else
            @plan.destroy!
            redirect_to "/admin/plans", notice: "Plan deleted."
          end
        end

        private

        def set_plan
          @plan = RSB::Entitlements::Plan.find(params[:id])
        end

        def plan_params
          permitted = params.require(:plan).permit(
            :name, :slug, :interval, :price_cents, :currency, :active,
            features: {},
            limits: {},
            metadata: {}
          )

          # Convert feature string values to booleans
          if permitted[:features].present?
            permitted[:features] = permitted[:features].transform_values { |v| v == "true" || v == true }
          end

          # Convert limit string values to integers
          if permitted[:limits].present?
            permitted[:limits] = permitted[:limits].transform_values { |v| v.to_i }
          end

          permitted
        end

        def authorize_plans
          authorize_admin_action!(resource: "plans", action: action_name)
        end
      end
    end
  end
end
