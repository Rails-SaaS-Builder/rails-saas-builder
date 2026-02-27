# frozen_string_literal: true

# Security Test: Admin Self-Privilege Escalation Prevention
#
# Attack vectors prevented:
# - Admin changing their own role via profile update
# - Limited admin promoting themselves via admin users controller
# - Limited admin editing roles to grant superadmin permissions
#
# Covers: SRS-016 US-015 (Privilege Escalation Prevention)

require 'test_helper'

class AdminPrivilegeEscalationTest < ActionDispatch::IntegrationTest
  setup do
    register_all_settings
    register_all_admin_categories
  end

  test 'profile update does not accept role_id parameter' do
    admin = create_test_admin!(permissions: { 'dashboard' => ['index'] })
    sign_in_admin(admin)

    superadmin_role = RSB::Admin::Role.create!(name: 'Super', permissions: { '*' => ['*'] })
    original_role_id = admin.role_id

    # Attempt to change own role via profile
    patch rsb_admin.profile_path, params: {
      admin_user: { role_id: superadmin_role.id }
    }

    admin.reload
    assert_equal original_role_id, admin.role_id,
      'Admin must not be able to change their own role via profile'
  end

  test 'admin without admin_users update permission cannot update another admin role' do
    # Admin only has dashboard access — no admin_users permission at all
    limited_admin = create_test_admin!(permissions: {
      'dashboard' => ['index']
    })
    target_admin = create_test_admin!(permissions: { 'dashboard' => ['index'] })
    superadmin_role = RSB::Admin::Role.create!(name: 'Super', permissions: { '*' => ['*'] })

    sign_in_admin(limited_admin)

    # Attempt to promote target admin to superadmin — RBAC should block this
    patch rsb_admin.admin_user_path(target_admin), params: {
      admin_user: { role_id: superadmin_role.id }
    }

    # RBAC must block the update
    assert_admin_forbidden_page
    target_admin.reload
    assert_not_equal superadmin_role.id, target_admin.role_id,
      'Admin without update permission must not be able to change other admin roles'
  end

  test 'profile params only permit email and password fields' do
    admin = create_test_admin!(superadmin: true)
    sign_in_admin(admin)

    # The profile controller should only permit :email, :password, :password_confirmation
    # Attempting to pass other fields should be silently ignored
    patch rsb_admin.profile_path, params: {
      admin_user: {
        email: 'new-email@example.com',
        password: 'newpassword1234',
        password_confirmation: 'newpassword1234',
        role_id: 999 # Should be ignored
      }
    }

    admin.reload
    assert_not_equal 999, admin.role_id, 'role_id must be ignored in profile update'
  end

  private

  def default_url_options
    { host: 'localhost' }
  end
end
