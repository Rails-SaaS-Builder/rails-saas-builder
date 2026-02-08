# frozen_string_literal: true

require 'test_helper'
require 'generators/rsb/admin/install/install_generator'
require 'rails/generators/test_case'

class InstallGeneratorTest < Rails::Generators::TestCase
  tests RSB::Admin::InstallGenerator
  destination File.expand_path('../tmp', __dir__)

  setup do
    prepare_destination
    RSB::Admin.reset!

    # Create minimal structure for route mounting
    FileUtils.mkdir_p(File.join(destination_root, 'config'))
    File.write(File.join(destination_root, 'config/routes.rb'), <<~RUBY)
      Rails.application.routes.draw do
      end
    RUBY

    # Create a no-op bin/rake so the generator's `rake` call doesn't error
    FileUtils.mkdir_p(File.join(destination_root, 'bin'))
    File.write(File.join(destination_root, 'bin/rake'), "#!/usr/bin/env ruby\n")
    FileUtils.chmod(0o755, File.join(destination_root, 'bin/rake'))
  end

  test 'copies seed file to db/seeds/rsb_admin.rb' do
    run_generator

    assert_file 'db/seeds/rsb_admin.rb' do |content|
      assert_match 'RSB::Admin::Role', content
      assert_match 'RSB::Admin::AdminUser', content
      assert_match 'Superadmin', content
      assert_match 'find_or_create_by!', content
    end
  end

  test 'does not overwrite existing seed file' do
    FileUtils.mkdir_p(File.join(destination_root, 'db/seeds'))
    File.write(File.join(destination_root, 'db/seeds/rsb_admin.rb'), '# custom seed')

    run_generator

    assert_file 'db/seeds/rsb_admin.rb' do |content|
      assert_equal '# custom seed', content.strip
    end
  end
end
