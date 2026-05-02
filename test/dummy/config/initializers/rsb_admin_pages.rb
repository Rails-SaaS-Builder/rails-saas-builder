# frozen_string_literal: true

# Registers a dummy-app-only "Entitlements Playground" admin page so an
# operator can drive consume/release flows against a real subject and watch
# the counters update + hooks fire in real time.
#
# Lives in the integration dummy app, never in the gem.
Rails.application.config.after_initialize do
  next unless defined?(RSB::Admin)

  # Register the page in the sidebar.
  RSB::Admin.registry.register_category 'Entitlements' do
    page :entitlements_playground,
         label: 'Playground',
         icon: 'play',
         controller: 'admin/entitlements_playground',
         actions: [
           { key: :index,   label: 'Playground' },
           { key: :consume, label: 'Consume' },
           { key: :release, label: 'Release' },
           { key: :reset,   label: 'Reset' }
         ]
  end

  # Register the dummy-app Organization model as an admin resource so an
  # operator can create / edit / delete subject rows from the UI without
  # dropping into a Rails console. Uses the standard rsb-admin
  # ResourcesController (no custom controller needed).
  RSB::Admin.registry.register_category 'Test data' do
    resource ::Organization,
             icon: 'building',
             actions: %i[index show new create edit update destroy] do
      column :id,         link: true
      column :name,       sortable: true
      column :created_at, formatter: :datetime
      column :updated_at, formatter: :datetime, visible_on: [:show]

      form_field :name, type: :text, required: true
    end
  end

  # Install a single, process-wide hook tap that pushes events into a
  # thread-local list when the playground controller has opted in. The
  # controller sets `Thread.current[:rsb_playground_capture] = []` before
  # the action and reads the array after.
  #
  # We register subscribers once at boot — HookRegistry has no #off API,
  # so re-registering in each request would leak subscribers.
  if defined?(RSB::Entitlements)
    format_arg = lambda do |arg|
      case arg
      when nil then 'nil'
      when String then arg
      when Numeric, Symbol, TrueClass, FalseClass then arg.to_s
      when Time, DateTime then arg.iso8601
      else
        if arg.respond_to?(:provider_subscription_id)
          "Sub##{arg.id}"
        elsif arg.class.respond_to?(:primary_key) && arg.respond_to?(:id)
          "#{arg.class.name}##{arg.id}"
        else
          arg.to_s
        end
      end
    end

    %i[overage_blocked release_blocked period_rolled
       plan_changed feature_archived plan_archived
       subscription_expired].each do |event|
      RSB::Entitlements.hooks.on(event) do |*args|
        capture = Thread.current[:rsb_playground_capture]
        next unless capture # not in playground context — skip silently

        summary = args.map { |a| format_arg.call(a) }.join(', ')
        capture << "#{event}(#{summary})"
      end
    end
  end
end
