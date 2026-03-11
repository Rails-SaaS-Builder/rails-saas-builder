# frozen_string_literal: true

module RSB
  module Auth
    module Google
      class SettingsSchema
        def self.build
          RSB::Settings::Schema.new('auth') do
            setting :'credentials.google.client_id',
                    type: :string,
                    default: '',
                    group: 'Google OAuth',
                    label: 'Client ID',
                    description: 'Google OAuth client ID from Google Cloud Console'

            setting :'credentials.google.client_secret',
                    type: :string,
                    default: '',
                    encrypted: true,
                    group: 'Google OAuth',
                    label: 'Client Secret',
                    description: 'Google OAuth client secret (stored encrypted)'

            setting :'credentials.google.auto_merge_by_email',
                    type: :boolean,
                    default: false,
                    group: 'Google OAuth',
                    label: 'Auto-merge by Email',
                    description: 'Automatically link Google to existing accounts with matching email'
          end
        end
      end
    end
  end
end
