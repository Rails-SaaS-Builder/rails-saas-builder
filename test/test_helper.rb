# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require_relative 'dummy/config/environment'
require 'rails/test_help'

# Include all gem test helpers
require 'rsb/settings/test_helper'
require 'rsb/auth/test_helper'
require 'rsb/entitlements/test_helper'
require 'rsb/admin/test_kit/helpers'
require 'rsb/auth/google/test_helper'

# Run all migrations from all sub-gems + dummy app
ActiveRecord::MigrationContext.new(
  Rails.application.config.paths['db/migrate'].to_a
).migrate
ActiveRecord::Migration.maintain_test_schema!

# Reset schema cache for models that may have been loaded before migrations ran
ActiveRecord::Base.descendants.each(&:reset_column_information)

module ActiveSupport
  class TestCase
    include RSB::Settings::TestHelper
    include RSB::Auth::TestHelper
    include RSB::Entitlements::TestHelper
    include RSB::Auth::Google::TestHelper

    # Re-register all settings schemas (needed after reset! clears registries between tests)
    def register_all_settings
      RSB::Settings.registry.register(RSB::Settings::SeoSettingsSchema.build)
      RSB::Settings.registry.register(RSB::Auth.settings_schema)
      RSB::Settings.registry.register(RSB::Entitlements.settings_schema)
      RSB::Settings.registry.register(RSB::Admin.settings_schema)
      RSB::Settings.registry.register(RSB::Auth::Google::SettingsSchema.build)
    end

    # Re-register all built-in credential types, per-credential enabled settings,
    # and last-type validation callbacks
    def register_all_credentials
      register_all_auth_credentials # all three types with icon/form_partial from RSB::Auth::TestHelper
      RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
      RSB::Auth::CredentialSettingsRegistrar.register_last_type_validation
    end

    # Re-register admin categories (on_load hooks only fire once at boot)
    def register_all_admin_categories
      RSB::Admin.registry.register_category 'Authentication' do
        resource RSB::Auth::Identity,
                 icon: 'users',
                 actions: %i[index show new create suspend activate deactivate
                             revoke_credential restore_credential restore
                             new_credential add_credential verify_credential resend_verification],
                 controller: 'rsb/auth/admin/identities',
                 per_page: 30,
                 default_sort: { column: :created_at, direction: :desc },
                 search_fields: [:id] do
          column :id, link: true
          column :status, formatter: :badge
          column :primary_identifier, label: 'Email / Username', visible_on: %i[index show]
          column :credentials_count, label: 'Credentials', visible_on: [:index]
          column :created_at, formatter: :datetime, visible_on: [:show]
          column :updated_at, formatter: :datetime, visible_on: [:show]

          filter :status, type: :select, options: %w[active suspended deactivated deleted]

          filter :credential, label: 'Email / Username / Phone', type: :text,
                              scope: lambda { |rel, val|
                                rel.joins(:credentials)
                                .where('rsb_auth_credentials.identifier LIKE ?', "%#{val}%")
                                .distinct
                              }

          filter :credential_type, label: 'Credential Type', type: :select,
                                   options: -> { RSB::Auth.credentials.all.map { |d| d.class_name.demodulize } },
                                   scope: lambda { |rel, val|
                                     rel.joins(:credentials)
                                     .where(rsb_auth_credentials: { type: "RSB::Auth::Credential::#{val}" })
                                     .distinct
                                   }
        end

        resource RSB::Auth::Invitation,
                 icon: 'mail',
                 controller: 'rsb/auth/admin/invitations',
                 actions: %i[index show new create revoke deliver redeliver extend_expiry] do
          column :id, link: true
          column :label
          column :status, formatter: :badge
          column :uses, visible_on: %i[index show]
          column :created_at, formatter: :datetime
          column :expires_at, formatter: :datetime
          column :token, visible_on: [:show]
          column :max_uses, visible_on: [:show]
          column :uses_count, visible_on: [:show]
          column :metadata, visible_on: [:show]
          column :invited_by_type, label: 'Invited By', visible_on: [:show]
          column :revoked_at, formatter: :datetime, visible_on: [:show]

          filter :status, type: :select, options: %w[pending exhausted expired revoked]
          filter :label, type: :text

          form_field :label, type: :text
          form_field :max_uses, type: :number, label: 'Max uses (0 = unlimited)'
          form_field :expires_in_hours, type: :number, label: 'Expires in (hours)'
          form_field :metadata, type: :textarea, label: 'Metadata (JSON)'
        end

        page :sessions_management,
             label: 'Active Sessions',
             icon: 'monitor',
             controller: 'rsb/auth/admin/sessions_management',
             actions: [
               { key: :index, label: 'Active Sessions' },
               { key: :destroy, label: 'Revoke', method: :delete }
             ]
      end

      RSB::Admin.registry.register_category 'Billing' do
        resource RSB::Entitlements::Plan,
                 icon: 'credit-card',
                 actions: %i[index show new create edit update destroy],
                 controller: 'rsb/entitlements/admin/plans',
                 default_sort: { column: :name, direction: :asc } do
          column :id, link: true
          column :key, sortable: true
          column :name, sortable: true
          column :display_order, visible_on: [:show]
          column :archived_at, formatter: :datetime, visible_on: [:show]
          column :created_at, formatter: :datetime, visible_on: [:show]

          filter :archived, type: :boolean

          form_field :key, type: :text, required: true, hint: 'URL-friendly identifier (immutable)'
          form_field :name, type: :text, required: true
          form_field :display_order, type: :number
        end

        resource RSB::Entitlements::Feature,
                 icon: 'toggle-left',
                 actions: %i[index show new create edit update archive unarchive],
                 controller: 'rsb/entitlements/admin/features',
                 default_sort: { column: :key, direction: :asc } do
          column :id, link: true
          column :key, sortable: true
          column :name, sortable: true
          column :kind, formatter: :badge
          column :unit, visible_on: [:show]
          column :archived_at, formatter: :datetime, visible_on: [:show]
          column :created_at, formatter: :datetime, visible_on: [:show]

          filter :kind, type: :select, options: %w[flag metered gauge]

          form_field :key, type: :text, required: true, hint: 'URL-friendly identifier (immutable)'
          form_field :name, type: :text, required: true
          form_field :kind, type: :select, options: %w[flag metered gauge], required: true
          form_field :unit, type: :text, hint: 'e.g. count, GB, request'
        end
      end
    end

    # Alias for test compatibility
    alias register_all_admin_categories_v2 register_all_admin_categories
    alias register_all_admin register_all_admin_categories
  end
end

module ActionDispatch
  class IntegrationTest
    include RSB::Settings::TestHelper
    include RSB::Auth::TestHelper
    include RSB::Entitlements::TestHelper
    include RSB::Admin::TestKit::Helpers
    include RSB::Auth::Google::TestHelper
  end
end
