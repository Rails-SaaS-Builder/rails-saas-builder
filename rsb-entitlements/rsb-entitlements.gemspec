require_relative 'lib/rsb/entitlements/version'

Gem::Specification.new do |spec|
  spec.name        = 'rsb-entitlements'
  spec.version     = RSB::Entitlements::VERSION
  spec.authors     = ['Aleksandr Marchenko']
  spec.email       = ['alex@marchenko.me']
  spec.homepage    = 'https://github.com/Rails-SaaS-Builder/rails-saas-builder'
  spec.summary     = 'Plans, entitlements & usage tracking for Rails SaaS Builder'
  spec.description = 'Flexible plan-based feature gating, entitlements, and metered usage tracking. Drop-in Entitleable concern for any model. Extensible provider registry for payment integrations.'
  spec.license     = 'LGPL-3.0'

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency 'rails', '>= 8.0'
  spec.add_dependency 'rsb-settings', RSB::Entitlements::VERSION

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  end
end
