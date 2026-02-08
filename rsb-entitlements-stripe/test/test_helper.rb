ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"
require "rsb/settings/test_helper"
require "rsb/entitlements/test_helper"

ActiveRecord::Migration.maintain_test_schema!

class ActiveSupport::TestCase
  include RSB::Settings::TestHelper
  include RSB::Entitlements::TestHelper
  include RSB::Entitlements::Stripe::TestHelper
end
