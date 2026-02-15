# frozen_string_literal: true

require_relative 'lib/rsb/version'

Gem::Specification.new do |spec|
  spec.name        = 'rails-saas-builder'
  spec.version     = RSB::VERSION
  spec.authors     = ['Aleksandr Marchenko']
  spec.email       = ['alex@marchenko.me']
  spec.homepage    = 'https://github.com/Rails-SaaS-Builder/rails-saas-builder'
  spec.summary     = 'Full-stack SaaS framework for Rails'
  spec.description = 'Wrapper gem that includes all RSB sub-gems: settings, auth, entitlements, admin. Like how the rails gem wraps activerecord, actionpack, etc.'
  spec.license     = 'LGPL-3.0'

  spec.required_ruby_version = '>= 3.2'

  spec.files = Dir['lib/**/*', 'LICENSE', 'Rakefile', 'README.md']

  spec.add_dependency 'rsb-admin', RSB::VERSION # Step 04
  spec.add_dependency 'rsb-auth', RSB::VERSION # Step 02
  spec.add_dependency 'rsb-entitlements', RSB::VERSION # Step 03
  spec.add_dependency 'rsb-settings', RSB::VERSION
end
