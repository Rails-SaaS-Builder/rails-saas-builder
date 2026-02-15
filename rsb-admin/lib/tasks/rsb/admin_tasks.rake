# frozen_string_literal: true

namespace :rsb do
  desc 'Create an admin user. Usage: rsb:create_admin EMAIL=admin@example.com PASSWORD=secret'
  task create_admin: :environment do
    email = ENV.fetch('EMAIL') { abort 'EMAIL is required' }
    password = ENV.fetch('PASSWORD') { abort 'PASSWORD is required' }

    # Create superadmin role if it doesn't exist
    role = RSB::Admin::Role.find_or_create_by!(name: 'Superadmin') do |r|
      r.permissions = { '*' => ['*'] }
      r.built_in = true
    end

    admin = RSB::Admin::AdminUser.create!(
      email: email,
      password: password,
      password_confirmation: password,
      role: role
    )
    puts "Admin user created: #{admin.email} (role: #{role.name})"
  end
end
