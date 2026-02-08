# frozen_string_literal: true

require "test_helper"

class AdminUserOtpTest < ActiveSupport::TestCase
  setup do
    @role = RSB::Admin::Role.create!(
      name: "Superadmin-#{SecureRandom.hex(4)}",
      permissions: { "*" => ["*"] }
    )
    @admin = RSB::Admin::AdminUser.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: @role
    )
  end

  # --- otp_enabled? ---

  test "otp_enabled? returns false by default" do
    refute @admin.otp_enabled?
  end

  test "otp_enabled? returns true when otp_secret and otp_required are set" do
    @admin.update!(otp_secret: ROTP::Base32.random, otp_required: true)
    assert @admin.otp_enabled?
  end

  test "otp_enabled? returns false when otp_required is false even with secret" do
    @admin.update!(otp_secret: ROTP::Base32.random, otp_required: false)
    refute @admin.otp_enabled?
  end

  test "otp_enabled? returns false when otp_secret is nil even with required true" do
    @admin.update!(otp_required: true)
    refute @admin.otp_enabled?
  end

  # --- generate_otp_secret! ---

  test "generate_otp_secret! returns a base32 secret" do
    secret = @admin.generate_otp_secret!
    assert secret.is_a?(String)
    assert secret.length > 0
    # Base32 characters
    assert_match(/\A[A-Z2-7=]+\z/, secret)
  end

  test "generate_otp_secret! does not save to database" do
    @admin.generate_otp_secret!
    @admin.reload
    assert_nil @admin.otp_secret
  end

  # --- verify_otp ---

  test "verify_otp returns true for valid current code" do
    secret = ROTP::Base32.random
    @admin.update!(otp_secret: secret, otp_required: true)

    totp = ROTP::TOTP.new(secret)
    code = totp.now

    assert @admin.verify_otp(code)
  end

  test "verify_otp returns false for invalid code" do
    secret = ROTP::Base32.random
    @admin.update!(otp_secret: secret, otp_required: true)

    refute @admin.verify_otp("000000")
  end

  test "verify_otp returns false when otp_secret is nil" do
    refute @admin.verify_otp("123456")
  end

  test "verify_otp allows drift of 30 seconds" do
    secret = ROTP::Base32.random
    @admin.update!(otp_secret: secret, otp_required: true)

    totp = ROTP::TOTP.new(secret)
    # Generate code for 30 seconds ago (within drift)
    code = totp.at(Time.now - 30)

    assert @admin.verify_otp(code)
  end

  # --- generate_backup_codes! ---

  test "generate_backup_codes! returns 10 plaintext codes" do
    codes = @admin.generate_backup_codes!
    assert_equal 10, codes.length
    codes.each do |code|
      assert_equal 8, code.length
      assert_match(/\A[a-zA-Z0-9]+\z/, code)
    end
  end

  test "generate_backup_codes! stores hashed codes in database" do
    codes = @admin.generate_backup_codes!
    @admin.reload

    stored = JSON.parse(@admin.otp_backup_codes)
    assert_equal 10, stored.length

    # Each stored code is a bcrypt hash, not plaintext
    stored.each do |hash|
      assert hash.start_with?("$2")
    end

    # Plaintext codes should NOT be in the stored array
    codes.each do |code|
      refute_includes stored, code
    end
  end

  # --- verify_backup_code ---

  test "verify_backup_code returns true and consumes valid code" do
    codes = @admin.generate_backup_codes!

    assert @admin.verify_backup_code(codes.first)

    # Code is consumed — second attempt fails
    refute @admin.verify_backup_code(codes.first)

    # Other codes still work
    assert @admin.verify_backup_code(codes[1])
  end

  test "verify_backup_code returns false for invalid code" do
    @admin.generate_backup_codes!
    refute @admin.verify_backup_code("invalidcode")
  end

  test "verify_backup_code returns false when no backup codes exist" do
    refute @admin.verify_backup_code("anything")
  end

  test "all 10 backup codes can be consumed one by one" do
    codes = @admin.generate_backup_codes!

    codes.each do |code|
      assert @admin.verify_backup_code(code), "Expected #{code} to verify"
    end

    # Now all are consumed
    @admin.reload
    stored = JSON.parse(@admin.otp_backup_codes)
    assert_equal 0, stored.length
  end

  # --- disable_otp! ---

  test "disable_otp! clears all OTP fields" do
    @admin.update!(
      otp_secret: ROTP::Base32.random,
      otp_required: true,
      otp_backup_codes: ["hash1", "hash2"].to_json
    )

    @admin.disable_otp!
    @admin.reload

    assert_nil @admin.otp_secret
    assert_equal false, @admin.otp_required
    assert_nil @admin.otp_backup_codes
  end

  # --- otp_provisioning_uri ---

  test "otp_provisioning_uri returns otpauth URI" do
    secret = ROTP::Base32.random
    uri = @admin.otp_provisioning_uri(secret, issuer: "TestApp")

    assert uri.start_with?("otpauth://totp/")
    assert_includes uri, "admin%40example.com"
    assert_includes uri, "issuer=TestApp"
    assert_includes uri, "secret=#{secret}"
  end
end
