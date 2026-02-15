# frozen_string_literal: true

require_relative 'lib/rsb/settings/version'

Gem::Specification.new do |spec|
  spec.name        = 'rsb-settings'
  spec.version     = RSB::Settings::VERSION
  spec.authors     = ['Aleksandr Marchenko']
  spec.email       = ['alex@marchenko.me']
  spec.homepage    = 'https://github.com/Rails-SaaS-Builder/rails-saas-builder'
  spec.summary     = 'Dynamic runtime settings with schema registry for Rails SaaS Builder'
  spec.description = 'Foundation gem for RSB. Provides a dynamic settings system with a schema registry that other gems register with. Settings resolve via DB → initializer → ENV → default.'
  spec.license     = 'LGPL-3.0'

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency 'rails', '>= 8.0'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  end
end
