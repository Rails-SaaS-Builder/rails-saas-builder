module RSB
  module Settings
    class Engine < ::Rails::Engine
      isolate_namespace RSB::Settings

      # Insert locale middleware into the Rails middleware stack.
      # Applies to all requests (host app + all engines).
      # Host app can remove: config.middleware.delete RSB::Settings::LocaleMiddleware
      initializer "rsb_settings.locale_middleware" do |app|
        app.middleware.use RSB::Settings::LocaleMiddleware
      end

      # Signal readiness — downstream gems hook in after this
      initializer "rsb_settings.ready" do
        # Registry is available. Other gems can now register schemas.
      end

      initializer "rsb_settings.register_seo_settings", after: "rsb_settings.ready" do
        RSB::Settings.registry.register(RSB::Settings::SeoSettingsSchema.build)
      end

      config.generators do |g|
        g.test_framework :minitest, fixture: false
        g.assets false
        g.helper false
      end
    end
  end
end
