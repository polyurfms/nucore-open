class CreateAdditionalPriceGroups < ActiveRecord::Migration[5.2]
  def change
    create_table :additional_price_groups do |t|
      t.integer :product_id
      t.string :name, null: false, limit: 50
      t.datetime   :deleted_at
      t.integer    :deleted_by
    end
  end
end
