require_relative 'lib/rsb/auth/version'

Gem::Specification.new do |spec|
  spec.name        = 'rsb-auth'
  spec.version     = RSB::Auth::VERSION
  spec.authors     = ['Aleksandr Marchenko']
  spec.email       = ['alex@marchenko.me']
  spec.homepage    = 'https://github.com/Rails-SaaS-Builder/rails-saas-builder'
  spec.summary     = 'Identity & authentication engine for Rails SaaS Builder'
  spec.description = 'Flexible identity system with pluggable credential types. Ships with email+password. Extensible via credential registry for OAuth, OTP, passkeys, etc.'
  spec.license     = 'LGPL-3.0'

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency 'bcrypt', '~> 3.1'
  spec.add_dependency 'rails', '>= 8.0'
  spec.add_dependency 'rsb-settings', RSB::Auth::VERSION
  spec.add_dependency 'useragent', '~> 0.16'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  end
end
