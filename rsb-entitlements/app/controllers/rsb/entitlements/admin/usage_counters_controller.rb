# frozen_string_literal: true

module RSB
  module Entitlements
    module Admin
      class UsageCountersController < RSB::Admin::AdminController
        # Displays a filterable, sortable, paginated table of usage counters.
        #
        # Params:
        #   metric (optional) - filter by metric name
        #   period_key (optional) - filter by period key
        #   countable_type (optional) - filter by countable type
        #   sort (optional) - sort column: "current_value", "period_key", "created_at"
        #   direction (optional) - sort direction: "asc", "desc"
        #   page (optional) - pagination page number
        #
        # @return [void]
        def index
          scope = RSB::Entitlements::UsageCounter.all

          scope = scope.for_metric(params[:metric]) if params[:metric].present?
          scope = scope.for_period(params[:period_key]) if params[:period_key].present?
          scope = scope.where(countable_type: params[:countable_type]) if params[:countable_type].present?

          sort_col = %w[current_value period_key created_at].include?(params[:sort]) ? params[:sort] : 'created_at'
          sort_dir = params[:direction] == 'asc' ? :asc : :desc
          scope = scope.order(sort_col => sort_dir)

          @per_page = 25
          @page = (params[:page] || 1).to_i
          @total_count = scope.count
          @usage_counters = scope.offset((@page - 1) * @per_page).limit(@per_page)

          @available_metrics = RSB::Entitlements::UsageCounter.distinct.pluck(:metric).sort
          @available_types = RSB::Entitlements::UsageCounter.distinct.pluck(:countable_type).sort
        end

        # Displays a per-metric trend chart using SQL aggregation.
        #
        # Params:
        #   metric (required for chart) - the metric to chart
        #   countable_type (optional) - filter to specific countable type
        #   countable_id (optional) - filter to specific countable
        #
        # @return [void]
        def trend
          @available_metrics = RSB::Entitlements::UsageCounter.distinct.pluck(:metric).sort
          @metric = params[:metric]

          return unless @metric.present?

          scope = RSB::Entitlements::UsageCounter.for_metric(@metric)
          scope = scope.where(countable_type: params[:countable_type]) if params[:countable_type].present?
          scope = scope.where(countable_id: params[:countable_id]) if params[:countable_id].present?

          @trend_data = scope
                        .group(:period_key)
                        .order(:period_key)
                        .sum(:current_value)
                        .to_a
                        .last(30)
                        .to_h

          @max_value = @trend_data.values.max || 0
        end
      end
    end
  end
end
