# frozen_string_literal: true

module RSB
  module Admin
    # Rails generator for scaffolding custom admin themes.
    #
    # This generator creates either a host-app theme (default) or a complete
    # Rails engine gem for distributable themes. Both modes include:
    # - CSS with all required `--rsb-admin-*` variables
    # - View overrides (sidebar and header)
    # - Theme registration code
    #
    # @example Generate a host-app theme
    #   rails generate rsb:admin:theme corporate
    #
    # @example Generate a theme as a Rails engine gem
    #   rails generate rsb:admin:theme corporate --engine
    class ThemeGenerator < Rails::Generators::NamedBase
      namespace 'rsb:admin:theme'
      source_root File.expand_path('templates', __dir__)

      desc 'Scaffold a new RSB Admin theme.'

      class_option :engine, type: :boolean, default: false,
                            desc: 'Generate as a Rails engine gem (for distribution)'

      # Creates the theme scaffold based on the `--engine` option.
      #
      # Dispatches to either {#create_host_app_scaffold} for host-app themes
      # or {#create_engine_scaffold} for engine gems.
      #
      # @return [void]
      def create_theme
        if options[:engine]
          create_engine_scaffold
        else
          create_host_app_scaffold
        end
      end

      # Prints post-generation instructions to the console.
      #
      # Instructions differ based on whether a host-app or engine scaffold
      # was generated.
      #
      # @return [void]
      def print_instructions
        say ''
        if options[:engine]
          say "Theme engine scaffold created at #{engine_dir}/", :green
          say ''
          say 'Next steps:'
          say "  1. cd #{engine_dir}"
          say "  2. Customize the CSS variables in app/assets/stylesheets/rsb/admin/themes/#{file_name}.css"
          say "  3. Customize views in app/views/rsb/admin/themes/#{file_name}/views/"
          say '  4. Build: bundle exec rake build'
          say "  5. Add to host app Gemfile: gem 'rsb-admin-#{file_name}-theme', path: '#{engine_dir}'"
        else
          say 'Theme scaffold created!', :green
          say ''
          say 'Next steps:'
          say "  1. Customize CSS variables in app/assets/stylesheets/admin/themes/#{file_name}.css"
          say "  2. Customize views in app/views/admin/themes/#{file_name}/views/"
          say "  3. Activate via Settings page or: RSB::Admin.configure { |c| c.theme = :#{file_name} }"
        end
        say ''
      end

      private

      # ── Host App Scaffold ──────────────────────────

      # Creates a host-app theme scaffold with CSS, views, and an initializer.
      #
      # Files created:
      # - `app/assets/stylesheets/admin/themes/{name}.css`
      # - `app/views/admin/themes/{name}/views/shared/_sidebar.html.erb`
      # - `app/views/admin/themes/{name}/views/shared/_header.html.erb`
      # - `config/initializers/rsb_admin_{name}_theme.rb`
      #
      # @return [void]
      # @api private
      def create_host_app_scaffold
        # CSS with all variables
        template 'theme.css.tt',
                 "app/assets/stylesheets/admin/themes/#{file_name}.css"

        # Copy default sidebar and header as starting points
        copy_engine_view('shared/_sidebar.html.erb',
                         "app/views/admin/themes/#{file_name}/views/shared/_sidebar.html.erb")
        copy_engine_view('shared/_header.html.erb',
                         "app/views/admin/themes/#{file_name}/views/shared/_header.html.erb")

        # Initializer to register the theme
        create_file "config/initializers/rsb_admin_#{file_name}_theme.rb", <<~RUBY
          RSB::Admin.register_theme :#{file_name},
            label: "#{class_name}",
            css: "admin/themes/#{file_name}",
            views_path: "admin/themes/#{file_name}/views"
        RUBY
      end

      # ── Engine Scaffold ────────────────────────────

      # Creates a complete Rails engine gem scaffold for the theme.
      #
      # Creates a directory structure with:
      # - Gemspec with `rsb-admin` dependency
      # - Engine class with theme registration
      # - CSS and view assets
      # - Gemfile and Rakefile
      #
      # @return [void]
      # @api private
      def create_engine_scaffold
        # Gemspec
        create_file "#{engine_dir}/rsb-admin-#{file_name}-theme.gemspec", <<~GEMSPEC
          Gem::Specification.new do |s|
            s.name        = "rsb-admin-#{file_name}-theme"
            s.version     = "0.1.0"
            s.summary     = "#{class_name} theme for RSB Admin"
            s.description = "A custom theme for the RSB Admin panel."
            s.license     = "MIT"
            s.authors     = ["TODO: Your name"]

            s.files = Dir["{app,lib}/**/*", "LICENSE", "README.md"]
            s.require_paths = ["lib"]

            s.add_dependency "rsb-admin"
          end
        GEMSPEC

        # Main lib file
        create_file "#{engine_dir}/lib/rsb/admin/#{file_name}_theme.rb", <<~RUBY
          require "rsb/admin/#{file_name}_theme/engine"
        RUBY

        # Engine
        create_file "#{engine_dir}/lib/rsb/admin/#{file_name}_theme/engine.rb", <<~RUBY
          module RSB
            module Admin
              module #{class_name}Theme
                class Engine < ::Rails::Engine
                  isolate_namespace RSB::Admin::#{class_name}Theme

                  initializer "rsb_admin_#{file_name}_theme.register" do
                    RSB::Admin.register_theme :#{file_name},
                      label: "#{class_name}",
                      css: "rsb/admin/themes/#{file_name}",
                      views_path: "rsb/admin/themes/#{file_name}/views"
                  end
                end
              end
            end
          end
        RUBY

        # CSS with all variables
        template 'theme.css.tt',
                 "#{engine_dir}/app/assets/stylesheets/rsb/admin/themes/#{file_name}.css"

        # Copy default sidebar and header as starting points
        copy_engine_view('shared/_sidebar.html.erb',
                         "#{engine_dir}/app/views/rsb/admin/themes/#{file_name}/views/shared/_sidebar.html.erb")
        copy_engine_view('shared/_header.html.erb',
                         "#{engine_dir}/app/views/rsb/admin/themes/#{file_name}/views/shared/_header.html.erb")

        # Gemfile
        create_file "#{engine_dir}/Gemfile", <<~GEMFILE
          source "https://rubygems.org"

          gemspec

          gem "rsb-admin", path: "../../"
        GEMFILE

        # Rakefile
        create_file "#{engine_dir}/Rakefile", <<~RAKE
          require "bundler/gem_tasks"
        RAKE
      end

      # Returns the directory name for the engine gem.
      #
      # @return [String] the engine directory name
      # @api private
      def engine_dir
        "rsb-admin-#{file_name}-theme"
      end

      # Returns the theme name (same as file_name).
      #
      # @return [String] the theme name
      # @api private
      def theme_name
        file_name
      end

      # Copies a view file from the RSB Admin engine to a destination path.
      #
      # If the source view doesn't exist in the engine, prints a skip message
      # instead of failing.
      #
      # @param relative_path [String] the view path relative to `rsb/admin/`
      # @param destination [String] the destination path for the copied view
      # @return [void]
      # @api private
      def copy_engine_view(relative_path, destination)
        source = RSB::Admin::Engine.root.join('app', 'views', 'rsb', 'admin', relative_path)
        if File.exist?(source)
          create_file destination, File.read(source)
        else
          say_status :skip, "#{relative_path} (source not found)", :yellow
        end
      end
    end
  end
end
