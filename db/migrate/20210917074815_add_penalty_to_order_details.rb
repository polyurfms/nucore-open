class AddPenaltyToOrderDetails < ActiveRecord::Migration[5.2]
  def change
    change_table :order_details do |t|
      t.decimal :penalty, precision: 13, scale: 2, default: 0, null: false
      t.decimal :early_end_discount , precision: 13, default: 0, scale: 2, null: false
    end
  end
end
