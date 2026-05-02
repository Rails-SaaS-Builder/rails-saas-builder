# frozen_string_literal: true

module RSB
  module Entitlements
    module Admin
      # Admin controller for Feature catalog management.
      #
      # Handles full CRUD plus archive/unarchive lifecycle actions.
      # All actions are RBAC-gated via +authorize_admin_action!+.
      #
      # Dispatched from rsb-admin's ResourcesController when the Feature
      # resource registration sets +controller: 'rsb/entitlements/admin/features'+.
      class FeaturesController < ::RSB::Admin::AdminController
        before_action :authorize_features
        before_action :set_feature, only: %i[show edit update archive unarchive]

        # GET /admin/features
        def index
          @page = [params[:page].to_i, 1].max
          @per_page = (params[:per_page] || 25).to_i
          @filter_values = params[:q]&.to_unsafe_h || {}

          scope = RSB::Entitlements::Feature.order(:key)
          scope = scope.where(kind: @filter_values['kind']) if @filter_values['kind'].present?

          scope = if @filter_values['archived'] == 'true'
                    scope.where.not(archived_at: nil)
                  else
                    scope.where(archived_at: nil)
                  end

          @features = scope.limit(@per_page).offset((@page - 1) * @per_page)
        end

        # GET /admin/features/:id
        def show; end

        # GET /admin/features/new
        def new
          @feature = RSB::Entitlements::Feature.new
        end

        # POST /admin/features
        def create
          @feature = RSB::Entitlements::Feature.new(feature_params)
          if @feature.save
            redirect_to rsb_admin_resource_show_path('features', @feature.id),
                        notice: t('rsb.entitlements.admin.features.created')
          else
            render :new, status: :unprocessable_entity
          end
        end

        # GET /admin/features/:id/edit
        def edit; end

        # PATCH /admin/features/:id
        def update
          # key and kind are immutable — only name and unit are editable.
          if @feature.update(feature_update_params)
            redirect_to rsb_admin_resource_show_path('features', @feature.id),
                        notice: t('rsb.entitlements.admin.features.updated')
          else
            render :edit, status: :unprocessable_entity
          end
        end

        # POST /admin/features/:id/archive
        def archive
          @feature.update!(archived_at: Time.current)
          redirect_to rsb_admin_resource_show_path('features', @feature.id),
                      notice: t('rsb.entitlements.admin.features.archived')
        rescue ActiveRecord::RecordInvalid => e
          redirect_to rsb_admin_resource_show_path('features', @feature.id), alert: e.message
        end

        # POST /admin/features/:id/unarchive
        def unarchive
          @feature.update!(archived_at: nil)
          redirect_to rsb_admin_resource_show_path('features', @feature.id),
                      notice: t('rsb.entitlements.admin.features.unarchived')
        rescue ActiveRecord::RecordInvalid => e
          redirect_to rsb_admin_resource_show_path('features', @feature.id), alert: e.message
        end

        private

        def set_feature
          @feature = RSB::Entitlements::Feature.find(params[:id])
        end

        def authorize_features
          authorize_admin_action!(resource: 'entitlements_features', action: action_name)
        end

        def feature_params
          params.require(:feature).permit(:key, :name, :kind, :unit)
        end

        def feature_update_params
          params.require(:feature).permit(:name, :unit)
        end
      end
    end
  end
end
