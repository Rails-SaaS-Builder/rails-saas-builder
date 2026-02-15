# frozen_string_literal: true

require_relative 'lib/rsb/entitlements/stripe/version'

Gem::Specification.new do |spec|
  spec.name        = 'rsb-entitlements-stripe'
  spec.version     = RSB::Entitlements::Stripe::VERSION
  spec.authors     = ['Aleksandr Marchenko']
  spec.email       = ['alex@marchenko.me']
  spec.homepage    = 'https://github.com/Rails-SaaS-Builder/rails-saas-builder'
  spec.summary     = 'Stripe payment provider for Rails SaaS Builder'
  spec.description = "Implements RSB's PaymentProvider interface using Stripe Checkout Sessions for one-time and subscription payments, with webhook-driven entitlement lifecycle management."
  spec.license     = 'LGPL-3.0'

  spec.metadata = {
    'source_code_uri' => 'https://github.com/Rails-SaaS-Builder/rails-saas-builder',
    'bug_tracker_uri' => 'https://github.com/Rails-SaaS-Builder/rails-saas-builder/issues',
    'changelog_uri' => 'https://github.com/Rails-SaaS-Builder/rails-saas-builder/blob/master/CHANGELOG.md'
  }

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency 'rails', '>= 8.0'
  spec.add_dependency 'rsb-entitlements', '>= 0.9.0'
  spec.add_dependency 'stripe', '~> 18.0'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  end
end
