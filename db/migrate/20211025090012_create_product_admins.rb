class CreateProductAdmins < ActiveRecord::Migration[5.2]
  def change
    create_table :product_admins do |t|
      t.references :product, foreign_key: true, type: :integer
      t.references :user, foreign_key: true, type: :integer
      t.timestamps

    end
  end
end
