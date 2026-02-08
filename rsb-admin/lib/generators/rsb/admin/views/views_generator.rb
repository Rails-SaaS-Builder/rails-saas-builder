# frozen_string_literal: true

module RSB
  module Admin
    # Generator to export RSB Admin views to the host application for customization.
    #
    # This generator copies view files from the RSB Admin engine (or a specific theme)
    # to the host application's view override path. It supports selective export via
    # `--only` group filtering and theme-specific views via `--theme`.
    #
    # @example Export all views
    #   rails generate rsb:admin:views
    #
    # @example Export only sidebar and header
    #   rails generate rsb:admin:views --only sidebar,header
    #
    # @example Export modern theme views
    #   rails generate rsb:admin:views --theme modern
    #
    # @example Force overwrite existing files
    #   rails generate rsb:admin:views --force
    class ViewsGenerator < Rails::Generators::Base
      namespace "rsb:admin:views"
      desc 'Export RSB Admin views to your application for customization.'

      class_option :only, type: :string, default: nil,
                          desc: 'Comma-separated list of view groups to export (sidebar,header,layout,breadcrumbs,resources,fields,dashboard,sessions)'
      class_option :theme, type: :string, default: nil,
                           desc: 'Export views for a specific theme (e.g., modern)'
      class_option :force, type: :boolean, default: false,
                           desc: 'Overwrite existing files'

      # Mapping of view groups to their file paths (relative to the views root).
      # Paths use the partial naming convention (with underscore prefix for partials).
      VIEW_GROUPS = {
        'sidebar' => ['shared/_sidebar.html.erb'],
        'header' => ['shared/_header.html.erb'],
        'layout' => ['layouts/rsb/admin/application.html.erb'],
        'breadcrumbs' => ['shared/_breadcrumbs.html.erb'],
        'resources' => [
          'resources/index.html.erb',
          'resources/show.html.erb',
          'resources/new.html.erb',
          'resources/edit.html.erb',
          'resources/_table.html.erb',
          'resources/_filters.html.erb',
          'resources/_form.html.erb',
          'resources/_pagination.html.erb'
        ],
        'fields' => [
          'shared/fields/_text.html.erb',
          'shared/fields/_textarea.html.erb',
          'shared/fields/_select.html.erb',
          'shared/fields/_checkbox.html.erb',
          'shared/fields/_number.html.erb',
          'shared/fields/_email.html.erb',
          'shared/fields/_password.html.erb',
          'shared/fields/_datetime.html.erb',
          'shared/fields/_json.html.erb'
        ],
        'dashboard' => ['dashboard/index.html.erb'],
        'sessions' => ['sessions/new.html.erb']
      }.freeze

      # Copies the selected view files from the engine to the host application.
      #
      # This is the main action that exports views, handling group filtering,
      # theme selection, and skip/force logic for existing files.
      #
      # @return [void]
      def copy_views
        groups = selected_groups
        source_root = resolve_source_root

        unless File.directory?(source_root)
          say_status :error, "Source directory not found: #{source_root}", :red
          return
        end

        files_copied = 0
        files_skipped = 0

        groups.each_value do |paths|
          paths.each do |relative_path|
            source = source_path_for(relative_path)
            destination = File.join(target_directory, relative_path)

            unless File.exist?(source)
              say_status :skip, "#{relative_path} (not found in source)", :yellow
              next
            end

            if File.exist?(destination) && !options[:force]
              say_status :skip, "#{relative_path} (already exists, use --force to overwrite)", :yellow
              files_skipped += 1
            else
              copy_file_with_status(source, destination)
              files_copied += 1
            end
          end
        end

        say ''
        say "Exported #{files_copied} view(s) to #{target_directory}/", :green
        say "Skipped #{files_skipped} existing file(s)." if files_skipped.positive?
      end

      # Sets up the view_overrides_path configuration if not already configured.
      #
      # Creates an initializer that configures the override path when the
      # configuration is currently nil. This ensures views exported to the
      # host app will be found by the engine.
      #
      # @return [void]
      def setup_override_path
        return if RSB::Admin.configuration.view_overrides_path.present?

        override_path = 'rsb_admin_overrides'
        initializer_path = 'config/initializers/rsb_admin_views.rb'

        if File.exist?(File.join(destination_root, initializer_path))
          say_status :skip, initializer_path, :yellow
          return
        end

        create_file initializer_path, <<~RUBY
          RSB::Admin.configure do |config|
            config.view_overrides_path = "#{override_path}"
          end
        RUBY

        say ''
        say "Created initializer to set view_overrides_path = \"#{override_path}\"", :green
      end

      # Prints instructions about the view override chain.
      #
      # Explains how the Rails view resolution works with the exported files,
      # helping developers understand the priority order.
      #
      # @return [void]
      def print_instructions
        say ''
        say 'View override chain (highest priority first):', :cyan
        say "  1. app/views/#{override_path_name}/ (your customizations)"
        say '  2. Theme views (if active theme has view overrides)'
        say '  3. RSB Admin engine defaults (fallback)'
        say ''
        say 'Edit the exported files to customize your admin panel.'
        say "Files you didn't export will continue using engine defaults."
        say ''
      end

      private

      # Returns the filtered set of view groups based on the `--only` option.
      #
      # If `--only` is not specified, returns all groups. If specified, validates
      # group names and exits with an error message if any invalid groups are found.
      #
      # @return [Hash{String => Array<String>}] filtered view groups hash
      # @raise [SystemExit] if invalid group names are provided
      def selected_groups
        if options[:only]
          keys = options[:only].split(',').map(&:strip)
          invalid = keys - VIEW_GROUPS.keys
          if invalid.any?
            say_status :error,
                       "Unknown view group(s): #{invalid.join(', ')}. Valid groups: #{VIEW_GROUPS.keys.join(', ')}", :red
            exit 1
          end
          VIEW_GROUPS.slice(*keys)
        else
          VIEW_GROUPS
        end
      end

      # Resolves the source root directory based on the `--theme` option.
      #
      # If a theme is specified, uses the theme's views_path if available,
      # otherwise falls back to engine defaults. If no theme is specified,
      # uses the engine's default view directory.
      #
      # @return [String] absolute path to the source view directory
      # @raise [SystemExit] if an invalid theme name is provided
      def resolve_source_root
        if options[:theme]
          theme_key = options[:theme].to_sym
          theme = RSB::Admin.themes[theme_key]
          if theme.nil?
            say_status :error, "Unknown theme: #{options[:theme]}. Available: #{RSB::Admin.themes.keys.join(', ')}",
                       :red
            exit 1
          end

          if theme.views_path
            # Theme has custom views — use them as source
            RSB::Admin::Engine.root.join('app', 'views', theme.views_path).to_s
          else
            # Theme has no custom views — fall back to engine defaults
            engine_views_root
          end
        else
          engine_views_root
        end
      end

      # Returns the full source path for a given relative view path.
      #
      # Handles the special case of layout files, which live under `app/views/layouts/`
      # instead of the namespaced view directory.
      #
      # @param relative_path [String] the relative path from VIEW_GROUPS
      # @return [String] absolute path to the source file
      def source_path_for(relative_path)
        if relative_path.start_with?('layouts/')
          RSB::Admin::Engine.root.join('app', 'views', relative_path).to_s
        else
          File.join(resolve_source_root, relative_path)
        end
      end

      # Returns the engine's default namespaced views root directory.
      #
      # @return [String] absolute path to rsb/admin view directory in the engine
      def engine_views_root
        RSB::Admin::Engine.root.join('app', 'views', 'rsb', 'admin').to_s
      end

      # Returns the target directory where views will be exported.
      #
      # Uses the configured view_overrides_path or the default "rsb_admin_overrides".
      #
      # @return [String] absolute path to the target view directory
      def target_directory
        File.join(destination_root, 'app', 'views', override_path_name)
      end

      # Returns the configured or default override path name.
      #
      # @return [String] the view override path name
      def override_path_name
        RSB::Admin.configuration.view_overrides_path || 'rsb_admin_overrides'
      end

      # Copies a file and prints a status message.
      #
      # Creates parent directories if needed and reports the relative path
      # that was created.
      #
      # @param source [String] absolute path to source file
      # @param destination [String] absolute path to destination file
      # @return [void]
      def copy_file_with_status(source, destination)
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(source, destination)
        relative = destination.sub("#{destination_root}/", '')
        say_status :create, relative, :green
      end
    end
  end
end
