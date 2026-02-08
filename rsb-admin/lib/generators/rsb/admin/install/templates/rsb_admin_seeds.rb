# RSB Admin Seed Data
#
# This file creates a default Superadmin role and initial admin user.
# Uncomment and customize the values below, then run:
#
#   rails db:seed
#
# Alternatively, use the rake task for a quick one-off setup:
#
#   rails rsb:create_admin EMAIL=admin@example.com PASSWORD=changeme
#

# role = RSB::Admin::Role.find_or_create_by!(name: "Superadmin") do |r|
#   r.permissions = { "*" => ["*"] }
#   r.built_in = true
# end
#
# RSB::Admin::AdminUser.find_or_create_by!(email: "admin@example.com") do |u|
#   u.password = "changeme123"
#   u.password_confirmation = "changeme123"
#   u.role = role
# end
