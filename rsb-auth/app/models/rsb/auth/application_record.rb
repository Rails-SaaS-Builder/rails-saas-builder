# frozen_string_literal: true

module RSB
  module Auth
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
      self.table_name_prefix = 'rsb_auth_'
    end
  end
end
