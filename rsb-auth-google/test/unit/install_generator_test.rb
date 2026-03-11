# frozen_string_literal: true

require 'test_helper'
require 'rails/generators/test_case'
require 'generators/rsb/auth/google/install/install_generator'

class RSB::Auth::Google::InstallGeneratorTest < Rails::Generators::TestCase
  tests RSB::Auth::Google::InstallGenerator
  destination File.expand_path('../tmp/generator_test', __dir__)

  setup do
    prepare_destination

    # Create a minimal routes.rb for the generator to modify
    FileUtils.mkdir_p(File.join(destination_root, 'config'))
    File.write(
      File.join(destination_root, 'config', 'routes.rb'),
      "Rails.application.routes.draw do\nend\n"
    )

    # Stub provider_uid check to skip migration (no DB in generator test context)
    RSB::Auth::Google::InstallGenerator.define_method(:provider_uid_column_exists?) { true }
  end

  teardown do
    # Restore original method
    RSB::Auth::Google::InstallGenerator.define_method(:provider_uid_column_exists?) do
      require 'active_record'
      ActiveRecord::Base.connection.column_exists?(:rsb_auth_credentials, :provider_uid)
    rescue StandardError
      false
    end
  end

  test 'creates initializer file' do
    run_generator

    assert_file 'config/initializers/rsb_auth_google.rb' do |content|
      assert_match(/RSB::Auth::Google\.configure/, content)
      assert_match(/config\.client_id/, content)
      assert_match(/config\.client_secret/, content)
    end
  end

  test 'mounts engine routes' do
    run_generator

    assert_file 'config/routes.rb' do |content|
      assert_match(/mount RSB::Auth::Google::Engine/, content)
      assert_match(%r{/auth/oauth/google}, content)
    end
  end

  test 'skips migration when provider_uid column exists' do
    output = run_generator
    assert_match(/provider_uid column already exists/, output)
  end
end
