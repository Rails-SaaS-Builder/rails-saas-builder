# frozen_string_literal: true

# Test controller for dashboard override functionality.
# Used by dashboard_override_test.rb to verify dashboard dispatch mechanism.
class TestDashboardController < RSB::Admin::AdminController
  # Renders plain text for testing dashboard override.
  def index
    render plain: 'Custom Dashboard Index'
  end

  # Custom action for testing dashboard sub-actions (tabs).
  def metrics
    render plain: 'Custom Dashboard Metrics'
  end

  private

  # Inherits breadcrumbs from request.env and adds action-specific breadcrumb.
  # This tests that breadcrumbs are correctly passed through Rack dispatch.
  #
  # @return [void]
  def build_breadcrumbs
    @breadcrumbs = request.env['rsb.admin.breadcrumbs'] || []
    add_breadcrumb('Metrics') if action_name == 'metrics'
  end
end
