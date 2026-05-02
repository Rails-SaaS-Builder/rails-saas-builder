# frozen_string_literal: true

module RSB
  module Entitlements
    module Admin
      # Admin controller for Plan catalog management.
      #
      # Handles full CRUD plus archive/unarchive lifecycle actions.
      # The show page also surfaces nested PlanFeature rows so admins
      # can inspect and manage feature grants inline.
      #
      # All actions are RBAC-gated via +authorize_admin_action!+.
      class PlansController < ::RSB::Admin::AdminController
        before_action :authorize_plans
        before_action :set_plan, only: %i[show edit update archive unarchive
                                          attach_feature edit_plan_feature destroy_plan_feature]
        before_action :set_plan_feature, only: %i[edit_plan_feature destroy_plan_feature]

        # GET /admin/plans
        def index
          @page = [params[:page].to_i, 1].max
          @per_page = (params[:per_page] || 25).to_i
          @filter_values = params[:q]&.to_unsafe_h || {}

          scope = RSB::Entitlements::Plan.order(:display_order, :key)

          scope = if @filter_values['archived'] == 'true'
                    scope.where.not(archived_at: nil)
                  else
                    scope.where(archived_at: nil)
                  end

          @plans = scope.limit(@per_page).offset((@page - 1) * @per_page)
        end

        # GET /admin/plans/:id
        def show
          @plan_features = RSB::Entitlements::PlanFeature
                           .where(plan_key: @plan.key)
                           .order(:feature_key)
          attached_keys = @plan_features.pluck(:feature_key)
          @available_features = RSB::Entitlements::Feature
                                .where(archived_at: nil)
                                .where.not(key: attached_keys)
                                .order(:key)
          @feature_kinds = RSB::Entitlements::Feature
                           .where(key: attached_keys)
                           .pluck(:key, :kind).to_h
        end

        # GET /admin/plans/new
        def new
          @plan = RSB::Entitlements::Plan.new
        end

        # POST /admin/plans
        def create
          @plan = RSB::Entitlements::Plan.new(plan_params)
          if @plan.save
            redirect_to rsb_admin_resource_show_path('plans', @plan.id),
                        notice: t('rsb.entitlements.admin.plans.created')
          else
            render :new, status: :unprocessable_entity
          end
        end

        # GET /admin/plans/:id/edit
        def edit; end

        # PATCH /admin/plans/:id
        def update
          # key is immutable — only name, display_order, metadata are editable.
          if @plan.update(plan_update_params)
            redirect_to rsb_admin_resource_show_path('plans', @plan.id),
                        notice: t('rsb.entitlements.admin.plans.updated')
          else
            render :edit, status: :unprocessable_entity
          end
        end

        # POST /admin/plans/:id/archive
        def archive
          @plan.update!(archived_at: Time.current)
          redirect_to rsb_admin_resource_show_path('plans', @plan.id),
                      notice: t('rsb.entitlements.admin.plans.archived')
        rescue ActiveRecord::RecordInvalid => e
          redirect_to rsb_admin_resource_show_path('plans', @plan.id), alert: e.message
        end

        # GET  /admin/plans/:id/attach_feature                  → step 1 (picker)
        # GET  /admin/plans/:id/attach_feature?feature_key=K    → step 2 (form)
        # POST /admin/plans/:id/attach_feature                  → create the PlanFeature
        #
        # Two-step server-driven attach flow. The POST creates the row and
        # always redirects back to /admin/plans/:id (success or failure).
        def attach_feature
          attached_keys = RSB::Entitlements::PlanFeature
                          .where(plan_key: @plan.key)
                          .pluck(:feature_key)

          if request.post?
            create_plan_feature_from_form(attached_keys)
          elsif params[:feature_key].present?
            render_attach_step2(attached_keys)
          else
            render_attach_step1(attached_keys)
          end
        end

        # GET   /admin/plans/:id/edit_plan_feature?plan_feature_id=X
        # PATCH /admin/plans/:id/edit_plan_feature?plan_feature_id=X
        def edit_plan_feature
          @feature = RSB::Entitlements::Feature.find_by(key: @plan_feature.feature_key)

          if request.patch?
            if @plan_feature.update(plan_feature_update_params(@feature&.kind))
              redirect_to rsb_admin_resource_show_path('plans', @plan.id),
                          notice: t('rsb.entitlements.admin.plan_features.updated')
            else
              render :edit_plan_feature, status: :unprocessable_entity
            end
          else
            render :edit_plan_feature
          end
        end

        # POST /admin/plans/:id/destroy_plan_feature?plan_feature_id=X
        def destroy_plan_feature
          @plan_feature.destroy!
          redirect_to rsb_admin_resource_show_path('plans', @plan.id),
                      notice: t('rsb.entitlements.admin.plan_features.deleted')
        end

        # POST /admin/plans/:id/unarchive
        def unarchive
          @plan.update!(archived_at: nil)
          redirect_to rsb_admin_resource_show_path('plans', @plan.id),
                      notice: t('rsb.entitlements.admin.plans.unarchived')
        rescue ActiveRecord::RecordInvalid => e
          redirect_to rsb_admin_resource_show_path('plans', @plan.id), alert: e.message
        end

        private

        def set_plan
          @plan = RSB::Entitlements::Plan.find(params[:id])
        end

        # Loads the PlanFeature identified by ?plan_feature_id=X and verifies
        # it belongs to @plan. Tampering with the id to point at a row from
        # a different plan returns 404, not a permission error.
        def set_plan_feature
          @plan_feature = RSB::Entitlements::PlanFeature
                          .where(plan_key: @plan.key)
                          .find(params[:plan_feature_id])
        end

        def authorize_plans
          authorize_admin_action!(resource: 'entitlements_plans', action: action_name)
        end

        def plan_params
          params.require(:plan).permit(:key, :name, :display_order, metadata: {})
        end

        def plan_update_params
          params.require(:plan).permit(:name, :display_order, metadata: {})
        end

        def render_attach_step1(attached_keys)
          @available_features = RSB::Entitlements::Feature
                                .where(archived_at: nil)
                                .where.not(key: attached_keys)
                                .order(:key)
          render :attach_feature_step1
        end

        def render_attach_step2(attached_keys)
          @feature = RSB::Entitlements::Feature
                     .where(archived_at: nil)
                     .where.not(key: attached_keys)
                     .find_by(key: params[:feature_key])
          unless @feature
            redirect_to "#{rsb_admin_resource_show_path('plans', @plan.id)}/attach_feature",
                        alert: t('rsb.entitlements.admin.plan_features.errors.feature_not_available')
            return
          end
          render :attach_feature_step2
        end

        # Creates the PlanFeature from the step-2 form POST. plan_key is
        # taken from the URL, never from form params, so the form cannot
        # be re-targeted to a different plan.
        def create_plan_feature_from_form(attached_keys)
          feature = RSB::Entitlements::Feature
                    .where(archived_at: nil)
                    .where.not(key: attached_keys)
                    .find_by(key: params.dig(:plan_feature, :feature_key))
          unless feature
            redirect_to "#{rsb_admin_resource_show_path('plans', @plan.id)}/attach_feature",
                        alert: t('rsb.entitlements.admin.plan_features.errors.feature_not_available')
            return
          end

          attrs = plan_feature_create_params(feature.kind).merge(
            plan_key: @plan.key, feature_key: feature.key
          )
          plan_feature = RSB::Entitlements::PlanFeature.new(attrs)
          if plan_feature.save
            redirect_to rsb_admin_resource_show_path('plans', @plan.id),
                        notice: t('rsb.entitlements.admin.plan_features.created')
          else
            redirect_to "#{rsb_admin_resource_show_path('plans', @plan.id)}/attach_feature?feature_key=#{feature.key}",
                        alert: plan_feature.errors.full_messages.to_sentence
          end
        end

        def plan_feature_create_params(kind)
          permitted = case kind
                      when 'flag'    then %i[enabled]
                      when 'metered' then %i[limit_value period]
                      when 'gauge'   then %i[limit_value]
                      else                %i[enabled limit_value period]
                      end
          params.require(:plan_feature).permit(*permitted)
        end

        def plan_feature_update_params(kind)
          plan_feature_create_params(kind)
        end
      end
    end
  end
end
