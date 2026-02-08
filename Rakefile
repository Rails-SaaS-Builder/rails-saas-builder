require "bundler/setup"
require "rake/testtask"

load File.expand_path("lib/tasks/release.rake", __dir__)

SUB_GEMS = %w[rsb-settings rsb-auth rsb-entitlements rsb-entitlements-stripe rsb-admin].freeze

desc "Run tests for all sub-gems"
task :test_subgems do
  SUB_GEMS.each do |gem_dir|
    puts "\n#{'=' * 60}"
    puts "Testing #{gem_dir}"
    puts '=' * 60
    Dir.chdir(gem_dir) do
      sh "bundle install --quiet"
      sh "bundle exec rake test"
    end
  end
end

Rake::TestTask.new(:test_integration) do |t|
  t.libs << "test"
  t.pattern = "test/integration/**/*_test.rb"
  t.verbose = false
end

desc "Run tests for a single sub-gem: rake test_gem GEM=rsb-admin"
task :test_gem do
  gem_name = ENV["GEM"] || abort("Usage: rake test_gem GEM=rsb-admin")
  abort("Unknown gem: #{gem_name}") unless SUB_GEMS.include?(gem_name)
  Dir.chdir(gem_name) do
    sh "bundle install --quiet"
    test_file = ENV["TEST"]
    if test_file
      sh "bundle exec ruby -Itest #{test_file}"
    else
      sh "bundle exec rake test"
    end
  end
end

desc "Run all tests (sub-gems + integration)"
task test: [:test_subgems, :test_integration]

task default: :test
