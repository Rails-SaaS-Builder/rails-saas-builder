# frozen_string_literal: true

module RSB
  module Entitlements
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
      self.table_name_prefix = 'rsb_entitlements_'
    end
  end
end
