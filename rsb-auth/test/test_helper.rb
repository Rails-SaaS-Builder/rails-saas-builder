# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require_relative 'dummy/config/environment'
require 'rails/test_help'
require 'rsb/settings/test_helper'
require 'rsb/auth/test_helper'
# Ensure migrations are up to date
ActiveRecord::Migration.maintain_test_schema!

module ActiveSupport
  class TestCase
    include RSB::Settings::TestHelper
    include RSB::Auth::TestHelper
  end
end
