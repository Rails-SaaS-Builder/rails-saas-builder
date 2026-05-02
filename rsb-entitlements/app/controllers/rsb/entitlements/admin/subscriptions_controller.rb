# frozen_string_literal: true

module RSB
  module Entitlements
    module Admin
      # Admin controller for Subscription management.
      #
      # Read-only for provider-driven subscriptions (stripe / apple / etc.) plus
      # two operator actions: create a manual subscription and cancel an active
      # subscription. Both flow through {Subscriptions.sync!} so the same hooks,
      # validations, and UPSERT semantics apply.
      class SubscriptionsController < ::RSB::Admin::AdminController
        before_action :authorize_subscriptions
        before_action :set_subscription, only: %i[show cancel]

        # GET /admin/subscriptions
        def index
          @page = [params[:page].to_i, 1].max
          @per_page = (params[:per_page] || 25).to_i
          @filter_values = params[:q]&.to_unsafe_h || {}

          scope = RSB::Entitlements::Subscription.order(created_at: :desc)
          %w[status provider plan_key subject_type].each do |key|
            scope = scope.where(key => @filter_values[key]) if @filter_values[key].present?
          end

          @subscriptions = scope.limit(@per_page).offset((@page - 1) * @per_page)
        end

        # GET /admin/subscriptions/:id
        def show; end

        # GET /admin/subscriptions/new — manual provider only.
        def new
          @subscription = RSB::Entitlements::Subscription.new(
            provider: 'manual',
            status: 'active',
            current_period_start: Time.current,
            current_period_end: 1.year.from_now,
            cancel_at_period_end: false
          )
          @available_plans = RSB::Entitlements::Plan.where(archived_at: nil).order(:display_order, :name)
        end

        # POST /admin/subscriptions
        def create
          subject_type = manual_params[:subject_type].to_s
          subject_id   = manual_params[:subject_id].to_s
          subject      = lookup_subject(subject_type, subject_id)
          unless subject
            redirect_to rsb_admin_resource_new_path('subscriptions'),
                        alert: t('rsb.entitlements.admin.subscriptions.errors.subject_not_found',
                                 type: subject_type, id: subject_id)
            return
          end

          row = RSB::Entitlements::Subscriptions.sync!(
            provider: 'manual',
            provider_subscription_id: "manual_#{SecureRandom.hex(8)}",
            subject: subject,
            plan_key: manual_params[:plan_key].to_s,
            status: manual_params[:status].to_s,
            current_period_start: parse_time(manual_params[:current_period_start]),
            current_period_end: parse_time(manual_params[:current_period_end]),
            trial_end: parse_time(manual_params[:trial_end]),
            cancel_at_period_end: ActiveModel::Type::Boolean.new.cast(manual_params[:cancel_at_period_end])
          )
          redirect_to rsb_admin_resource_show_path('subscriptions', row.id),
                      notice: t('rsb.entitlements.admin.subscriptions.created')
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => e
          @subscription = RSB::Entitlements::Subscription.new(manual_params)
          @available_plans = RSB::Entitlements::Plan.where(archived_at: nil).order(:display_order, :name)
          flash.now[:alert] = e.message
          render :new, status: :unprocessable_entity
        end

        # POST /admin/subscriptions/:id/cancel
        def cancel
          unless @subscription.status.in?(%w[active trialing])
            redirect_to rsb_admin_resource_show_path('subscriptions', @subscription.id),
                        alert: t('rsb.entitlements.admin.subscriptions.errors.cannot_cancel',
                                 status: @subscription.status)
            return
          end

          RSB::Entitlements::Subscriptions.sync!(
            provider: @subscription.provider,
            provider_subscription_id: @subscription.provider_subscription_id,
            subject: lookup_subject(@subscription.subject_type, @subscription.subject_id) || @subscription,
            plan_key: @subscription.plan_key,
            status: 'canceled',
            current_period_start: @subscription.current_period_start,
            current_period_end: @subscription.current_period_end,
            trial_end: @subscription.trial_end,
            cancel_at_period_end: @subscription.cancel_at_period_end,
            canceled_at: Time.current
          )
          redirect_to rsb_admin_resource_show_path('subscriptions', @subscription.id),
                      notice: t('rsb.entitlements.admin.subscriptions.canceled')
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ArgumentError => e
          redirect_to rsb_admin_resource_show_path('subscriptions', @subscription.id), alert: e.message
        end

        private

        def set_subscription
          @subscription = RSB::Entitlements::Subscription.find(params[:id])
        end

        def authorize_subscriptions
          authorize_admin_action!(resource: 'entitlements_subscriptions', action: action_name)
        end

        def manual_params
          params.require(:subscription).permit(
            :subject_type, :subject_id, :plan_key, :status,
            :current_period_start, :current_period_end, :trial_end,
            :cancel_at_period_end
          )
        end

        # Looks up a polymorphic subject by type-name and id. Returns nil if
        # the type doesn't constantize, the row doesn't exist, or the model
        # doesn't include {RSB::Entitlements::Subject} (which would mean the
        # ergonomic `subject:` kwarg can't read its own back-reference).
        def lookup_subject(subject_type, subject_id)
          klass = subject_type.to_s.safe_constantize
          return nil unless klass.is_a?(Class) && klass < ActiveRecord::Base

          klass.find_by(id: subject_id)
        end

        def parse_time(value)
          return nil if value.blank?

          Time.zone.parse(value.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
