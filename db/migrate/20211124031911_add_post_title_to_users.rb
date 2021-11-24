class AddPostTitleToUsers < ActiveRecord::Migration[5.2]
  def change
    change_table :users do |t|
      t.string :post_title, limit: 255
    end
  end
end
