class RemarkToProductUser < ActiveRecord::Migration[5.2]
  def change
    change_table :product_users do |t|
      t.string "remark" , limit: 200
    end
  end
end
