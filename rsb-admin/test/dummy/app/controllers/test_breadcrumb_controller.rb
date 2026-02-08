# frozen_string_literal: true

# Test controller for verifying breadcrumb inheritance through Rack dispatch.
# Used by breadcrumb integration tests to confirm that custom page controllers
# receive breadcrumb context from ResourcesController via request.env.
class TestBreadcrumbController < RSB::Admin::AdminController
  # Renders the admin layout with breadcrumbs to verify inheritance.
  # Breadcrumbs are inherited from request.env['rsb.admin.breadcrumbs']
  # via AdminController#build_breadcrumbs.
  def index
    # Breadcrumbs inherited from request.env['rsb.admin.breadcrumbs']
  end

  # Custom action for testing page sub-action breadcrumb inheritance.
  # Appends the action name to inherited breadcrumbs.
  def custom
    # Breadcrumbs inherited from request.env['rsb.admin.breadcrumbs']
    add_breadcrumb("Custom Action")
  end
end
