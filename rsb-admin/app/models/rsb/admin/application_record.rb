module RSB
  module Admin
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
      self.table_name_prefix = "rsb_admin_"
    end
  end
end
