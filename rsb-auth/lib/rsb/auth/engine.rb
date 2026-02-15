module RSB
  module Auth
    class Engine < ::Rails::Engine
      isolate_namespace RSB::Auth

      # FIXME: Move admin integration to separate gem!
      # Exclude admin controllers from autoloading when rsb-admin is not present.
      # These controllers inherit from RSB::Admin::AdminController and can only
      # be loaded when rsb-admin is in the bundle.
      initializer 'rsb_auth.exclude_admin_controllers', before: :set_autoload_paths do
        unless defined?(RSB::Admin::Engine)
          Rails.autoloaders.main.ignore(root.join('app', 'controllers', 'rsb', 'auth', 'admin'))
        end
      end

      # Register settings schema with rsb-settings
      initializer 'rsb_auth.register_settings', after: 'rsb_settings.ready' do
        RSB::Settings.registry.register(RSB::Auth.settings_schema)
      end

      # Register built-in credential types
      initializer 'rsb_auth.register_credentials' do
        RSB::Auth.credentials.register(
          CredentialDefinition.new(
            key: :email_password,
            class_name: 'RSB::Auth::Credential::EmailPassword',
            authenticatable: true,
            registerable: true,
            label: 'Email & Password',
            icon: 'mail',
            form_partial: 'rsb/auth/credentials/email_password',
            admin_form_partial: 'rsb/auth/admin/credentials/email_password'
          )
        )

        RSB::Auth.credentials.register(
          CredentialDefinition.new(
            key: :username_password,
            class_name: 'RSB::Auth::Credential::UsernamePassword',
            authenticatable: true,
            registerable: true,
            label: 'Username & Password',
            icon: 'user',
            form_partial: 'rsb/auth/credentials/username_password',
            admin_form_partial: 'rsb/auth/admin/credentials/username_password'
          )
        )

        # Auto-register per-credential enabled settings
        RSB::Auth::CredentialSettingsRegistrar.register_enabled_settings
      end

      # Signal readiness — downstream gems (rsb-auth-oauth, etc.) hook in after this
      initializer 'rsb_auth.ready' do
        # Credential registry is populated. Extensions can now register.
        # Register validation callback to prevent disabling the last credential type
        RSB::Auth::CredentialSettingsRegistrar.register_last_type_validation
      end

      # Apply identity and credential concerns from configuration.
      #
      # Concerns are applied in the +to_prepare+ block, which re-runs on each
      # request in development (supporting code reloading) and once in production.
      # Identity concerns are **prepended** so they can override model methods
      # (e.g. +complete?+). Credential concerns are **included** on the base
      # class and inherited by all STI subtypes. Concerns are applied in array
      # order — later concerns override methods from earlier ones (standard Ruby
      # method resolution).
      #
      # @see RSB::Auth::Configuration#identity_concerns
      # @see RSB::Auth::Configuration#credential_concerns
      initializer 'rsb_auth.apply_concerns', after: 'rsb_auth.ready' do
        config.to_prepare do
          RSB::Auth.configuration.identity_concerns.each do |concern|
            RSB::Auth::Identity.prepend(concern) unless RSB::Auth::Identity.ancestors.include?(concern)
          end

          RSB::Auth.configuration.credential_concerns.each do |concern|
            RSB::Auth::Credential.include(concern) unless RSB::Auth::Credential.ancestors.include?(concern)
          end
        end
      end

      # Load i18n locales for admin interface
      #
      # This initializer registers translation files from the engine's config/locales
      # directory with Rails' i18n system, enabling localized labels for admin
      # resources, columns, and actions.
      #
      # @example Translation lookup for admin resources
      #   I18n.t("rsb.admin.resources.identities.label") #=> "Identities"
      initializer 'rsb_auth.i18n' do
        config.i18n.load_path += Dir[RSB::Auth::Engine.root.join('config', 'locales', '**', '*.yml')]
      end

      # Admin integration via lazy on_load hook
      #
      # This initializer registers rsb-auth resources (Identity, Invitation) and
      # pages (sessions_management) with the RSB Admin panel using the enhanced
      # registration DSL. Resources include explicit column, filter, and form field
      # definitions to control how data is displayed and edited in the admin interface.
      #
      # The on_load hook ensures this code only runs if rsb-admin is present in the
      # host application. If rsb-admin is not available, this block is silently skipped.
      #
      # @example Accessing registered Identity resource
      #   registration = RSB::Admin.registry.find_resource(RSB::Auth::Identity)
      #   registration.columns.map(&:key) #=> [:id, :status, :primary_identifier, ...]
      initializer 'rsb_auth.admin_hooks' do
        ActiveSupport.on_load(:rsb_admin) do |admin_registry|
          admin_registry.register_category 'Authentication' do
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

              # Identity doesn't have generic forms — managed via credentials
              # No form_field declarations = auto-detect fallback
            end

            resource RSB::Auth::Invitation,
                     icon: 'mail',
                     actions: %i[index new create revoke] do
              column :id, link: true
              column :email
              column :token, visible_on: [:show]
              column :status, formatter: :badge, visible_on: [:index]
              column :invited_by_type, label: 'Invited By', visible_on: [:show]
              column :expires_at, formatter: :datetime
              column :accepted_at, formatter: :datetime, visible_on: [:show]

              filter :email, type: :text
              filter :status, type: :select, options: %w[pending accepted expired revoked]

              form_field :email, type: :email, required: true
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
