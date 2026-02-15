# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class AdminSessionTest < ActiveSupport::TestCase
  setup do
    @role = RSB::Admin::Role.create!(name: "Superadmin-#{SecureRandom.hex(4)}", permissions: { '*' => ['*'] })
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      role: @role
    )
  end

  # ── Validations ────────────────────────────────────

  test 'valid session' do
    session = RSB::Admin::AdminSession.new(
      admin_user: @admin,
      session_token: SecureRandom.urlsafe_base64(32),
      last_active_at: Time.current
    )
    assert session.valid?
  end

  test 'generates session_token on create' do
    session = RSB::Admin::AdminSession.create!(
      admin_user: @admin,
      last_active_at: Time.current
    )
    assert_not_nil session.session_token
    assert session.session_token.length > 20
  end

  test 'session_token must be unique' do
    token = SecureRandom.urlsafe_base64(32)
    RSB::Admin::AdminSession.create!(
      admin_user: @admin,
      session_token: token,
      last_active_at: Time.current
    )
    duplicate = RSB::Admin::AdminSession.new(
      admin_user: @admin,
      session_token: token,
      last_active_at: Time.current
    )
    refute duplicate.valid?
    assert_includes duplicate.errors[:session_token], 'has already been taken'
  end

  test 'requires admin_user' do
    session = RSB::Admin::AdminSession.new(
      session_token: SecureRandom.urlsafe_base64(32),
      last_active_at: Time.current
    )
    refute session.valid?
  end

  test 'requires last_active_at' do
    session = RSB::Admin::AdminSession.new(
      admin_user: @admin,
      session_token: SecureRandom.urlsafe_base64(32)
    )
    refute session.valid?
  end

  # ── parse_user_agent ───────────────────────────────

  test 'parse_user_agent detects Chrome on macOS' do
    ua = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    result = RSB::Admin::AdminSession.parse_user_agent(ua)
    assert_equal 'Chrome', result[:browser]
    assert_equal 'macOS', result[:os]
    assert_equal 'desktop', result[:device_type]
  end

  test 'parse_user_agent detects Firefox on Windows' do
    ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0'
    result = RSB::Admin::AdminSession.parse_user_agent(ua)
    assert_equal 'Firefox', result[:browser]
    assert_equal 'Windows', result[:os]
    assert_equal 'desktop', result[:device_type]
  end

  test 'parse_user_agent detects Safari on iOS (mobile)' do
    ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
    result = RSB::Admin::AdminSession.parse_user_agent(ua)
    assert_equal 'Safari', result[:browser]
    assert_equal 'iOS', result[:os]
    assert_equal 'mobile', result[:device_type]
  end

  test 'parse_user_agent detects Edge' do
    ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0'
    result = RSB::Admin::AdminSession.parse_user_agent(ua)
    assert_equal 'Edge', result[:browser]
    assert_equal 'Windows', result[:os]
  end

  test 'parse_user_agent detects Android tablet' do
    ua = 'Mozilla/5.0 (Linux; Android 13; SM-X200) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    result = RSB::Admin::AdminSession.parse_user_agent(ua)
    assert_equal 'Chrome', result[:browser]
    assert_equal 'Android', result[:os]
    assert_equal 'tablet', result[:device_type]
  end

  test 'parse_user_agent handles nil user_agent' do
    result = RSB::Admin::AdminSession.parse_user_agent(nil)
    assert_equal 'Unknown', result[:browser]
    assert_equal 'Unknown', result[:os]
    assert_equal 'desktop', result[:device_type]
  end

  test 'parse_user_agent handles empty string' do
    result = RSB::Admin::AdminSession.parse_user_agent('')
    assert_equal 'Unknown', result[:browser]
    assert_equal 'Unknown', result[:os]
    assert_equal 'desktop', result[:device_type]
  end

  # ── create_from_request! ───────────────────────────

  test 'create_from_request! creates session with parsed info' do
    mock_request = OpenStruct.new(
      remote_ip: '192.168.1.1',
      user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    )
    session = RSB::Admin::AdminSession.create_from_request!(admin_user: @admin, request: mock_request)

    assert session.persisted?
    assert_equal @admin.id, session.admin_user_id
    assert_equal '192.168.1.1', session.ip_address
    assert_equal 'Chrome', session.browser
    assert_equal 'macOS', session.os
    assert_equal 'desktop', session.device_type
    assert_not_nil session.session_token
    assert_not_nil session.last_active_at
  end

  # ── current? ───────────────────────────────────────

  test 'current? returns true for matching token' do
    session = RSB::Admin::AdminSession.create!(
      admin_user: @admin,
      session_token: 'my-token',
      last_active_at: Time.current
    )
    assert session.current?('my-token')
    refute session.current?('other-token')
  end

  # ── touch_activity! ────────────────────────────────

  test 'touch_activity! updates last_active_at' do
    session = RSB::Admin::AdminSession.create!(
      admin_user: @admin,
      last_active_at: 1.hour.ago
    )
    old_time = session.last_active_at

    session.touch_activity!
    session.reload

    assert session.last_active_at > old_time
  end

  # ── AdminUser association ──────────────────────────

  test 'admin_user has_many admin_sessions' do
    RSB::Admin::AdminSession.create!(admin_user: @admin, last_active_at: Time.current)
    RSB::Admin::AdminSession.create!(admin_user: @admin, last_active_at: Time.current)

    assert_equal 2, @admin.admin_sessions.count
  end

  test 'destroying admin_user destroys sessions' do
    RSB::Admin::AdminSession.create!(admin_user: @admin, last_active_at: Time.current)
    assert_equal 1, RSB::Admin::AdminSession.where(admin_user: @admin).count

    @admin.destroy
    assert_equal 0, RSB::Admin::AdminSession.where(admin_user_id: @admin.id).count
  end
end
