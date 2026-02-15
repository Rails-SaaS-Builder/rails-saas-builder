# frozen_string_literal: true

require_relative 'lib/rsb/admin/version'

Gem::Specification.new do |spec|
  spec.name        = 'rsb-admin'
  spec.version     = RSB::Admin::VERSION
  spec.authors     = ['Aleksandr Marchenko']
  spec.email       = ['alex@marchenko.me']
  spec.homepage    = 'https://github.com/Rails-SaaS-Builder/rails-saas-builder'
  spec.summary     = 'Lightweight admin panel framework for Rails SaaS Builder'
  spec.description = 'Registrable admin panel with dynamic RBAC, settings page, and a test kit for extension developers. Simpler than ActiveAdmin — designed for extensibility.'
  spec.license     = 'LGPL-3.0'

  spec.metadata = {
    'source_code_uri' => 'https://github.com/Rails-SaaS-Builder/rails-saas-builder',
    'bug_tracker_uri' => 'https://github.com/Rails-SaaS-Builder/rails-saas-builder/issues',
    'changelog_uri' => 'https://github.com/Rails-SaaS-Builder/rails-saas-builder/blob/master/CHANGELOG.md'
  }

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency 'bcrypt', '~> 3.1'
  spec.add_dependency 'rails', '>= 8.0'
  spec.add_dependency 'rotp', '~> 6.3'
  spec.add_dependency 'rqrcode', '~> 2.2'
  spec.add_dependency 'rsb-settings', RSB::Admin::VERSION

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  end
end
