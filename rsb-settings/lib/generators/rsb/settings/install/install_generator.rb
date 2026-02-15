# frozen_string_literal: true

module RSB
  module Settings
    class InstallGenerator < Rails::Generators::Base
      namespace 'rsb:settings:install'
      source_root File.expand_path('templates', __dir__)

      desc 'Install rsb-settings: copy migrations, create initializer.'

      def copy_migrations
        rake 'rsb_settings:install:migrations'
      end

      def create_initializer
        template 'initializer.rb', 'config/initializers/rsb_settings.rb'
      end

      def print_post_install
        say ''
        say 'rsb-settings installed successfully!', :green
        say ''
        say 'Next steps:'
        say '  1. rails db:migrate'
        say '  2. Settings are ready — other RSB gems will register their schemas automatically.'
        say ''
      end
    end
  end
end
