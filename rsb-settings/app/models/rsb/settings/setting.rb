module RSB
  module Settings
    class Setting < ActiveRecord::Base
      self.table_name = "rsb_settings_settings"

      encrypts :value

      validates :category, presence: true
      validates :key, presence: true, uniqueness: { scope: :category }

      scope :for_category, ->(cat) { where(category: cat.to_s) }

      def self.get(category, key)
        find_by(category: category.to_s, key: key.to_s)&.value
      end

      def self.set(category, key, value)
        record = find_or_initialize_by(category: category.to_s, key: key.to_s)
        record.update!(value: value.to_s)
        record
      end
    end
  end
end
