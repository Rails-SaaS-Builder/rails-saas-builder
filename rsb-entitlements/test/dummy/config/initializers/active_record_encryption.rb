# frozen_string_literal: true

Rails.application.config.active_record.encryption.primary_key = 'test-primary-key-for-rsb-entitlements'
Rails.application.config.active_record.encryption.deterministic_key = 'test-deterministic-key-for-rsb'
Rails.application.config.active_record.encryption.key_derivation_salt = 'test-key-derivation-salt-for-rsb'
