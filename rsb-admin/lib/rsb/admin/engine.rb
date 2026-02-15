# frozen_string_literal: true

module RSB
  module Admin
    class Engine < ::Rails::Engine
      isolate_namespace RSB::Admin

      initializer 'rsb_admin.i18n' do
        config.i18n.load_path += Dir[RSB::Admin::Engine.root.join('config', 'locales', '**', '*.yml')]
      end

      # Register settings schema
      initializer 'rsb_admin.register_settings', after: 'rsb_settings.ready' do
        RSB::Settings.registry.register(RSB::Admin.settings_schema)
      end

      # Trigger on_load hooks — this is where rsb-auth, rsb-entitlements,
      # and third-party gems register their admin sections.
      # Deferred to after_initialize so all engine autoload paths are set up
      # and model constants (e.g. RSB::Auth::Identity) are resolvable.
      initializer 'rsb_admin.ready' do |app|
        app.config.after_initialize do
          ActiveSupport.run_load_hooks(:rsb_admin, RSB::Admin.registry)
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
