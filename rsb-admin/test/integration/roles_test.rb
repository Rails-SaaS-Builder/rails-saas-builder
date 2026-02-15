# frozen_string_literal: true

require 'test_helper'

class RolesTest < ActionDispatch::IntegrationTest
  setup do
    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { '*' => ['*'] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: @role
    )
    post rsb_admin.login_path, params: { email: @admin.email, password: 'password123' }
  end

  test 'index shows all roles' do
    get rsb_admin.roles_path
    assert_response :success
    assert_select 'h1', 'Roles'
  end

  test 'new form renders' do
    get rsb_admin.new_role_path
    assert_response :success
    assert_select 'h1', 'New Role'
  end

  test 'create saves a role with valid data' do
    assert_difference 'RSB::Admin::Role.count', 1 do
      post rsb_admin.roles_path, params: {
        role: {
          name: 'Editor',
          permissions_json: '{"articles": ["index", "show"]}'
        }
      }
    end

    role = RSB::Admin::Role.find_by(name: 'Editor')
    assert_not_nil role
    assert_equal({ 'articles' => %w[index show] }, role.permissions)
    assert_redirected_to rsb_admin.role_path(role)
  end

  test 'create with invalid data re-renders form' do
    assert_no_difference 'RSB::Admin::Role.count' do
      post rsb_admin.roles_path, params: {
        role: { name: '', permissions_json: '{}' }
      }
    end
    assert_response :unprocessable_entity
  end

  test 'show renders role details' do
    get rsb_admin.role_path(@role)
    assert_response :success
    assert_match @role.name, response.body
  end

  test 'edit form renders' do
    get rsb_admin.edit_role_path(@role)
    assert_response :success
    assert_match @role.name, response.body
  end

  test 'update modifies the role' do
    patch rsb_admin.role_path(@role), params: {
      role: { name: 'Updated Name' }
    }
    assert_redirected_to rsb_admin.role_path(@role)
    assert_equal 'Updated Name', @role.reload.name
  end

  test 'destroy removes the role' do
    deletable = RSB::Admin::Role.create!(name: "Deletable-#{SecureRandom.hex(4)}", permissions: { 'x' => ['y'] })
    assert_difference 'RSB::Admin::Role.count', -1 do
      delete rsb_admin.role_path(deletable)
    end
    assert_redirected_to rsb_admin.roles_path
  end

  test 'destroy fails when role has admin users' do
    role_with_users = RSB::Admin::Role.create!(name: "InUse-#{SecureRandom.hex(4)}", permissions: { '*' => ['*'] })
    RSB::Admin::AdminUser.create!(email: "linked-#{SecureRandom.hex(4)}@example.com", password: 'password123',
                                  password_confirmation: 'password123', role: role_with_users)

    assert_no_difference 'RSB::Admin::Role.count' do
      delete rsb_admin.role_path(role_with_users)
    end
    assert_redirected_to rsb_admin.roles_path
  end
end
