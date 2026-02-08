ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"
require "rsb/settings/test_helper"
require "rsb/admin/test_kit/helpers"

# Ensure migrations are up to date
ActiveRecord::Migration.maintain_test_schema!

class ActiveSupport::TestCase
  include RSB::Settings::TestHelper

  teardown do
    RSB::Admin::AdminSession.delete_all
    RSB::Admin::AdminUser.delete_all
    RSB::Admin::Role.delete_all
    RSB::Admin.reset!
  end
end
