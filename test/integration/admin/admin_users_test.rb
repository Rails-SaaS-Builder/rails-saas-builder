# frozen_string_literal: true

require 'test_helper'

class AdminAdminUsersTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_test_admin!(superadmin: true)
    sign_in_admin(@admin)
  end

  # --- Index ---

  test 'index lists all admin users' do
    get rsb_admin.admin_users_path
    assert_response :success
    assert_match @admin.email, response.body
  end

  test 'index shows role name for each admin' do
    get rsb_admin.admin_users_path
    assert_response :success
    # The admin created by create_test_admin! has a role
    assert_match @admin.role.name, response.body
  end

  # --- Show ---

  test 'show displays admin user details' do
    get rsb_admin.admin_user_path(@admin)
    assert_response :success
    assert_match @admin.email, response.body
  end

  # --- New / Create ---

  test 'new renders the form' do
    get rsb_admin.new_admin_user_path
    assert_response :success
    assert_match 'Email', response.body
    assert_match 'Password', response.body
  end

  test 'create with valid params creates an admin user' do
    role = RSB::Admin::Role.create!(name: 'Editor', permissions: { 'identities' => ['index'] })

    assert_difference 'RSB::Admin::AdminUser.count', 1 do
      post rsb_admin.admin_users_path, params: {
        admin_user: {
          email: 'newadmin@example.com',
          password: 'secure-password-123',
          password_confirmation: 'secure-password-123',
          role_id: role.id
        }
      }
    end

    assert_redirected_to rsb_admin.admin_user_path(RSB::Admin::AdminUser.last)
    assert_equal 'newadmin@example.com', RSB::Admin::AdminUser.last.email
    assert_equal role, RSB::Admin::AdminUser.last.role
  end

  test 'create with invalid params re-renders form with errors' do
    post rsb_admin.admin_users_path, params: {
      admin_user: { email: '', password: 'short' }
    }

    assert_response :unprocessable_entity
    assert_match 'error', response.body.downcase
  end

  test 'create with duplicate email shows error' do
    post rsb_admin.admin_users_path, params: {
      admin_user: {
        email: @admin.email,
        password: 'secure-password-123',
        password_confirmation: 'secure-password-123'
      }
    }

    assert_response :unprocessable_entity
  end

  # --- Edit / Update ---

  test 'edit renders the form with existing values' do
    get rsb_admin.edit_admin_user_path(@admin)
    assert_response :success
    assert_match @admin.email, response.body
  end

  test 'update changes email' do
    other_admin = create_test_admin!(superadmin: true, email: 'other@example.com')

    patch rsb_admin.admin_user_path(other_admin), params: {
      admin_user: { email: 'updated@example.com' }
    }

    assert_redirected_to rsb_admin.admin_user_path(other_admin)
    other_admin.reload
    assert_equal 'updated@example.com', other_admin.email
  end

  test 'update with password changes password' do
    other_admin = create_test_admin!(superadmin: true, email: 'pass-test@example.com')

    patch rsb_admin.admin_user_path(other_admin), params: {
      admin_user: { password: 'new-password-123', password_confirmation: 'new-password-123' }
    }

    assert_redirected_to rsb_admin.admin_user_path(other_admin)
    other_admin.reload
    assert other_admin.authenticate('new-password-123')
  end

  test 'update without password does not clear password' do
    other_admin = create_test_admin!(superadmin: true, email: 'no-pass-change@example.com')

    patch rsb_admin.admin_user_path(other_admin), params: {
      admin_user: { email: 'still-works@example.com' }
    }

    assert_redirected_to rsb_admin.admin_user_path(other_admin)
    other_admin.reload
    assert other_admin.authenticate('test-password-secure') # original password from create_test_admin!
  end

  test 'update can change role' do
    other_admin = create_test_admin!(superadmin: true, email: 'role-change@example.com')
    editor_role = RSB::Admin::Role.create!(name: "Editor #{SecureRandom.hex(4)}",
                                           permissions: { 'identities' => ['index'] })

    patch rsb_admin.admin_user_path(other_admin), params: {
      admin_user: { role_id: editor_role.id }
    }

    other_admin.reload
    assert_equal editor_role, other_admin.role
  end

  # --- Destroy ---

  test 'destroy deletes an admin user' do
    other_admin = create_test_admin!(superadmin: true, email: 'delete-me@example.com')

    assert_difference 'RSB::Admin::AdminUser.count', -1 do
      delete rsb_admin.admin_user_path(other_admin)
    end

    assert_redirected_to rsb_admin.admin_users_path
  end

  test 'destroy cannot delete yourself' do
    assert_no_difference 'RSB::Admin::AdminUser.count' do
      delete rsb_admin.admin_user_path(@admin)
    end

    assert_redirected_to rsb_admin.admin_users_path
    follow_redirect!
    assert_match 'cannot delete your own account', response.body.downcase
  end

  # --- RBAC ---

  test 'restricted admin cannot access admin users' do
    restricted = create_test_admin!(permissions: { 'other' => ['index'] })
    sign_in_admin(restricted)

    get rsb_admin.admin_users_path
    assert_includes [302, 403], response.status
  end
end
