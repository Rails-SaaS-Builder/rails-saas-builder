ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"
require "rsb/settings/test_helper"

# Ensure migrations are up to date
ActiveRecord::Migration.maintain_test_schema!

class ActiveSupport::TestCase
  include RSB::Settings::TestHelper
end
