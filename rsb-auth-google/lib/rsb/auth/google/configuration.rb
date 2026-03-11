# frozen_string_literal: true

module RSB
  module Auth
    module Google
      class Configuration
        attr_accessor :client_id, :client_secret

        def initialize
          @client_id = nil
          @client_secret = nil
        end
      end
    end
  end
end
