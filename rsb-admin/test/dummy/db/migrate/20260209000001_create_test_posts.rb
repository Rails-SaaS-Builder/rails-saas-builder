class CreateTestPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :test_posts do |t|
      t.string :title, null: false
      t.text :body
      t.string :status, default: "draft"
      t.string :token            # sensitive column for exclusion testing
      t.boolean :published, default: false
      t.json :metadata, default: {}
      t.timestamps
    end
  end
end
