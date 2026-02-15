# frozen_string_literal: true

require 'test_helper'

class ProfileTest < ActionDispatch::IntegrationTest
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

  # ── Show ─────────────────────────────────────────

  test 'GET /admin/profile renders profile page' do
    get rsb_admin.profile_path
    assert_response :success
    assert_match @admin.email, response.body
    assert_match @role.name, response.body
  end

  test 'profile show displays role name' do
    get rsb_admin.profile_path
    assert_response :success
    assert_match @role.name, response.body
  end

  test 'profile show displays no role message when role is nil' do
    @admin.update_columns(role_id: nil)
    get rsb_admin.profile_path
    assert_response :success
    assert_match I18n.t('rsb.admin.admin_users.no_role'), response.body
  end

  test 'profile show has edit button' do
    get rsb_admin.profile_path
    assert_response :success
    assert_match rsb_admin.edit_profile_path, response.body
  end

  # ── Edit ─────────────────────────────────────────

  test 'GET /admin/profile/edit renders edit form' do
    get rsb_admin.edit_profile_path
    assert_response :success
    assert_select "input[name='admin_user[email]']"
    assert_select "input[name='current_password']"
    assert_select "input[name='admin_user[password]']"
    assert_select "input[name='admin_user[password_confirmation]']"
  end

  test 'edit form does not have role field' do
    get rsb_admin.edit_profile_path
    assert_response :success
    assert_select "select[name='admin_user[role_id]']", count: 0
    assert_select "input[name='admin_user[role_id]']", count: 0
  end

  # ── Update Email ─────────────────────────────────

  test 'update email with correct current password' do
    new_email = "new-#{SecureRandom.hex(4)}@example.com"
    patch rsb_admin.profile_path, params: {
      admin_user: { email: new_email },
      current_password: 'password123'
    }
    assert_redirected_to rsb_admin.profile_path
    follow_redirect!
    assert_match I18n.t('rsb.admin.profile.verification_sent'), response.body

    @admin.reload
    # Email should NOT be updated immediately - verification required
    refute_equal new_email, @admin.email
    # pending_email should be set
    assert_equal new_email, @admin.pending_email
  end

  test 'update email fails with wrong current password' do
    patch rsb_admin.profile_path, params: {
      admin_user: { email: 'changed@example.com' },
      current_password: 'wrongpassword'
    }
    assert_response :unprocessable_entity
    assert_match I18n.t('rsb.admin.profile.password_incorrect'), response.body

    @admin.reload
    refute_equal 'changed@example.com', @admin.email
  end

  test 'update email fails with empty current password' do
    patch rsb_admin.profile_path, params: {
      admin_user: { email: 'changed@example.com' },
      current_password: ''
    }
    assert_response :unprocessable_entity
  end

  test 'update email fails when email already taken' do
    other = RSB::Admin::AdminUser.create!(
      email: "other-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: @role
    )

    patch rsb_admin.profile_path, params: {
      admin_user: { email: other.email },
      current_password: 'password123'
    }
    assert_response :unprocessable_entity

    @admin.reload
    refute_equal other.email, @admin.email
  end

  # ── Update Password ──────────────────────────────

  test 'update password with correct current password' do
    patch rsb_admin.profile_path, params: {
      admin_user: { password: 'newpassword123', password_confirmation: 'newpassword123' },
      current_password: 'password123'
    }
    assert_redirected_to rsb_admin.profile_path

    @admin.reload
    assert @admin.authenticate('newpassword123')
  end

  test 'update password fails with wrong current password' do
    patch rsb_admin.profile_path, params: {
      admin_user: { password: 'newpassword123', password_confirmation: 'newpassword123' },
      current_password: 'wrongpassword'
    }
    assert_response :unprocessable_entity

    @admin.reload
    assert @admin.authenticate('password123') # original password unchanged
  end

  test 'update password fails when confirmation does not match' do
    patch rsb_admin.profile_path, params: {
      admin_user: { password: 'newpassword123', password_confirmation: 'mismatch' },
      current_password: 'password123'
    }
    assert_response :unprocessable_entity

    @admin.reload
    assert @admin.authenticate('password123')
  end

  test 'blank password fields update only email' do
    new_email = "emailonly-#{SecureRandom.hex(4)}@example.com"
    patch rsb_admin.profile_path, params: {
      admin_user: { email: new_email, password: '', password_confirmation: '' },
      current_password: 'password123'
    }
    assert_redirected_to rsb_admin.profile_path

    @admin.reload
    # Email should NOT be updated immediately - verification required
    refute_equal new_email, @admin.email
    # pending_email should be set
    assert_equal new_email, @admin.pending_email
    assert @admin.authenticate('password123') # password unchanged
  end

  # ── Session Persistence ──────────────────────────

  test 'session remains valid after password change' do
    patch rsb_admin.profile_path, params: {
      admin_user: { password: 'newpassword123', password_confirmation: 'newpassword123' },
      current_password: 'password123'
    }
    assert_redirected_to rsb_admin.profile_path
    follow_redirect!
    assert_response :success  # still authenticated, not redirected to login

    get rsb_admin.dashboard_path
    assert_response :success  # still has valid session
  end

  # ── No RBAC Required ─────────────────────────────

  test 'admin with no role can access profile' do
    no_role_admin = RSB::Admin::AdminUser.create!(
      email: "norole-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: nil
    )
    # Sign out current admin, sign in no-role admin
    delete rsb_admin.logout_path
    post rsb_admin.login_path, params: { email: no_role_admin.email, password: 'password123' }

    get rsb_admin.profile_path
    assert_response :success
    assert_match no_role_admin.email, response.body
  end

  test 'admin with no role can edit profile' do
    no_role_admin = RSB::Admin::AdminUser.create!(
      email: "norole-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: nil
    )
    delete rsb_admin.logout_path
    post rsb_admin.login_path, params: { email: no_role_admin.email, password: 'password123' }

    get rsb_admin.edit_profile_path
    assert_response :success
  end

  test 'admin with no role can update profile' do
    no_role_admin = RSB::Admin::AdminUser.create!(
      email: "norole-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: nil
    )
    delete rsb_admin.logout_path
    post rsb_admin.login_path, params: { email: no_role_admin.email, password: 'password123' }

    new_email = "norole-new-#{SecureRandom.hex(4)}@example.com"
    patch rsb_admin.profile_path, params: {
      admin_user: { email: new_email },
      current_password: 'password123'
    }
    assert_redirected_to rsb_admin.profile_path

    no_role_admin.reload
    # Email should NOT be updated immediately - verification required
    refute_equal new_email, no_role_admin.email
    # pending_email should be set
    assert_equal new_email, no_role_admin.pending_email
  end

  # ── Breadcrumbs ──────────────────────────────────

  test 'profile show breadcrumbs' do
    get rsb_admin.profile_path
    assert_response :success
    # Profile as last item (bold, no link)
    assert_select 'nav.flex span.font-medium', text: I18n.t('rsb.admin.profile.title')
  end

  test 'profile edit breadcrumbs include edit' do
    get rsb_admin.edit_profile_path
    assert_response :success
    # Profile as link (intermediate)
    assert_select "nav.flex a[href='#{rsb_admin.profile_path}']", text: I18n.t('rsb.admin.profile.title')
    # Edit as last item (bold, no link)
    assert_select 'nav.flex span.font-medium', text: I18n.t('rsb.admin.shared.edit')
  end

  # ── Role not changeable via profile ──────────────

  test 'role_id param is not permitted in profile update' do
    other_role = RSB::Admin::Role.create!(name: "Other-#{SecureRandom.hex(4)}", permissions: {})
    patch rsb_admin.profile_path, params: {
      admin_user: { role_id: other_role.id },
      current_password: 'password123'
    }
    # Should redirect successfully (role_id silently ignored)
    assert_redirected_to rsb_admin.profile_path

    @admin.reload
    assert_equal @role.id, @admin.role_id # role unchanged
  end
end
