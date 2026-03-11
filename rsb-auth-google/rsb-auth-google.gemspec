# frozen_string_literal: true

require_relative 'lib/rsb/auth/google/version'

Gem::Specification.new do |spec|
  spec.name        = 'rsb-auth-google'
  spec.version     = RSB::Auth::Google::VERSION
  spec.authors     = ['Aleksandr Marchenko']
  spec.email       = ['alex@marchenko.me']
  spec.homepage    = 'https://github.com/Rails-SaaS-Builder/rails-saas-builder'
  spec.summary     = 'Google OAuth authentication for Rails SaaS Builder'
  spec.description = "Adds Google OAuth as a credential type to RSB's auth system. Registers into the credential registry, provides OAuth redirect/callback endpoints, and verifies id_tokens via Google JWKS."
  spec.license     = 'LGPL-3.0'

  spec.metadata = {
    'source_code_uri' => 'https://github.com/Rails-SaaS-Builder/rails-saas-builder',
    'bug_tracker_uri' => 'https://github.com/Rails-SaaS-Builder/rails-saas-builder/issues',
    'changelog_uri' => 'https://github.com/Rails-SaaS-Builder/rails-saas-builder/blob/master/CHANGELOG.md'
  }

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency 'rails', '>= 8.0'
  spec.add_dependency 'rsb-auth', '>= 0.9.0'
  spec.add_dependency 'jwt', '~> 2.9'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  end
end
