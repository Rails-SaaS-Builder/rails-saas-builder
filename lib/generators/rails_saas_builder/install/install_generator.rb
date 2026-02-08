module RailsSaasBuilder
  class InstallGenerator < Rails::Generators::Base
    desc 'Install Rails SaaS Builder: runs all sub-gem install generators.'

    def install_settings
      say 'Installing rsb-settings...', :green
      generate 'rsb:settings:install'
    end

    def install_auth
      say 'Installing rsb-auth...', :green
      generate 'rsb:auth:install'
    end

    def install_entitlements
      say 'Installing rsb-entitlements...', :green
      generate 'rsb:entitlements:install'
    end

    def install_admin
      say 'Installing rsb-admin...', :green
      generate 'rsb:admin:install'
    end

    def print_post_install
      say ''
      say 'Rails SaaS Builder installed successfully!', :green
      say ''
      say 'Next steps:'
      say '  1. rails db:migrate'
      say '  2. rails rsb:create_admin EMAIL=admin@example.com PASSWORD=changeme'
      say '  3. Visit /admin/login for the admin panel'
      say '  4. Visit /auth/register for user registration'
      say ''
      say 'For documentation: https://github.com/Rails-SaaS-Builder/rails-saas-builder'
      say ''
    end
  end
end
