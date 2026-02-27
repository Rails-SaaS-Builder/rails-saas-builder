# frozen_string_literal: true

module RSB
  module Settings
    # Raised when attempting to set a value for a locked setting key.
    # Locked keys are configured via RSB::Settings.configure { |c| c.lock("category.key") }
    # and cannot be modified programmatically or via the admin UI.
    class LockedSettingError < StandardError; end
  end
end
