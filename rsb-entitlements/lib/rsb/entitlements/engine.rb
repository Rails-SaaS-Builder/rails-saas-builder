# frozen_string_literal: true

module RSB
  module Entitlements
    class Engine < ::Rails::Engine
      isolate_namespace RSB::Entitlements

      # Exclude admin controllers from autoloading when rsb-admin is not in
      # the bundle. Task 16 owns the actual admin controllers; the path is
      # reserved here so neither presence nor absence of rsb-admin breaks
      # boot.
      initializer 'rsb_entitlements.exclude_admin_controllers', before: :set_autoload_paths do
        unless defined?(RSB::Admin::Engine)
          Rails.autoloaders.main.ignore(root.join('app', 'controllers', 'rsb', 'entitlements', 'admin'))
        end
      end

      # Register settings schema with rsb-settings (empty schema in v1).
      initializer 'rsb_entitlements.register_settings', after: 'rsb_settings.ready' do
        RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
      end

      # Load i18n translations for admin labels.
      initializer 'rsb_entitlements.i18n' do
        config.i18n.load_path += Dir[
          RSB::Entitlements::Engine.root.join('config', 'locales', '**', '*.yml')
        ]
      end

      # Admin integration via lazy on_load hook — v1 schema.
      # Registers the "Entitlements" category with Feature/Plan/Subscription/
      # UsageCounter/ProviderEvent resources.
      # Feature and Plan use custom controllers (archive/unarchive).
      # Subscription, UsageCounter, and ProviderEvent are read-only via the
      # standard ResourcesController.
      # PlanFeature is NOT registered as a sidebar entry (inline on Plan show only).
      initializer 'rsb_entitlements.admin_hooks' do # rubocop:disable Metrics/BlockLength
        ActiveSupport.on_load(:rsb_admin) do |admin_registry|
          admin_registry.register_category 'Entitlements' do
            resource RSB::Entitlements::Feature,
                     icon: 'key',
                     controller: 'rsb/entitlements/admin/features',
                     actions: %i[index show new create edit update archive unarchive],
                     default_sort: { column: :key, direction: :asc } do
              column :id,          link: true, visible_on: [:show]
              column :key,         sortable: true
              column :name
              column :kind,        formatter: :badge
              column :unit,        visible_on: %i[index show]
              column :archived_at, formatter: :datetime, label: 'Archived'
              column :created_at,  formatter: :datetime, visible_on: [:show]

              filter :kind,     type: :select, options: %w[flag metered gauge]
              filter :archived, type: :select, options: %w[false true]

              form_field :key,  type: :text,   required: true,
                                hint: 'Lowercase, dot-segmented (e.g. api_calls)'
              form_field :name, type: :text,   required: true
              form_field :kind, type: :select, options: %w[flag metered gauge], required: true
              form_field :unit, type: :text,   hint: 'Free-form display label; null for flag'
            end

            resource RSB::Entitlements::Plan,
                     icon: 'layers',
                     controller: 'rsb/entitlements/admin/plans',
                     actions: %i[index show new create edit update archive unarchive
                                 attach_feature edit_plan_feature destroy_plan_feature],
                     default_sort: { column: :display_order, direction: :asc } do
              column :id,            link: true, visible_on: [:show]
              column :key,           sortable: true
              column :name
              column :display_order, label: 'Order', sortable: true
              column :archived_at,   formatter: :datetime, label: 'Archived'
              column :metadata,      formatter: :json, visible_on: [:show]
              column :created_at,    formatter: :datetime, visible_on: [:show]

              filter :archived, type: :select, options: %w[false true]

              form_field :key,           type: :text,   required: true
              form_field :name,          type: :text,   required: true
              form_field :display_order, type: :number
              form_field :metadata,      type: :json
            end

            resource RSB::Entitlements::Subscription,
                     icon: 'credit-card',
                     controller: 'rsb/entitlements/admin/subscriptions',
                     actions: %i[index show new create cancel],
                     default_sort: { column: :created_at, direction: :desc },
                     per_page: 25 do
              column :id,                      link: true
              column :subject_type,             label: 'Subject'
              column :subject_id,               label: 'Subject ID', visible_on: %i[index show]
              column :plan_key,                 sortable: true
              column :status,                   formatter: :badge
              column :provider,                 formatter: :badge
              column :provider_subscription_id, label: 'Provider Sub ID', visible_on: [:show]
              column :provider_customer_id,     label: 'Provider Customer ID', visible_on: [:show]
              column :current_period_start,     formatter: :datetime, visible_on: [:show]
              column :current_period_end,       formatter: :datetime
              column :trial_end,                formatter: :datetime, visible_on: [:show]
              column :cancel_at_period_end,     formatter: :badge, visible_on: [:show]
              column :canceled_at,              formatter: :datetime, visible_on: [:show]
              column :raw_state,                formatter: :json_collapsed, visible_on: [:show]
              column :created_at,               formatter: :datetime, visible_on: [:show]
              column :updated_at,               formatter: :datetime, visible_on: [:show]

              filter :status,       type: :select,
                                    options: %w[incomplete trialing active past_due canceled expired]
              filter :provider,     type: :text
              filter :plan_key,     type: :text
              filter :subject_type, type: :text
            end

            resource RSB::Entitlements::UsageCounter,
                     icon: 'bar-chart',
                     actions: %i[index show],
                     default_sort: { column: :updated_at, direction: :desc },
                     per_page: 50 do
              column :id,           link: true, visible_on: [:show]
              column :subject_type, label: 'Subject'
              column :subject_id,   label: 'Subject ID'
              column :feature_key,  sortable: true
              column :consumed
              column :period_start,
                     formatter: ->(value) { value.respond_to?(:strftime) ? value.strftime('%B %d, %Y at %I:%M %p') : '—' }
              column :updated_at,   formatter: :datetime

              filter :feature_key,  type: :text
              filter :subject_type, type: :text
            end

            resource RSB::Entitlements::ProviderEvent,
                     icon: 'inbox',
                     actions: %i[index show],
                     default_sort: { column: :processed_at, direction: :desc },
                     per_page: 50 do
              column :id,           link: true, visible_on: [:show]
              column :provider,     formatter: :badge
              column :event_id,     label: 'Event ID'
              column :type
              column :processed_at, formatter: :datetime
              column :payload,      formatter: :json_collapsed, visible_on: [:show]

              filter :provider, type: :text
              filter :type,     type: :text
            end

            # PlanFeature is NOT registered as an admin resource. Its CUD
            # lifecycle is owned by PlansController via plan-scoped custom
            # actions (attach_feature, edit_plan_feature, destroy_plan_feature)
            # so all redirects land back on the parent Plan show page.
          end
        end
      end

      config.generators do |g|
        g.test_framework :minitest, fixture: false
        g.assets false
        g.helper false
      end
    end
  end
end
