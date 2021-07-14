class OrderDetails < ActiveRecord::Migration[5.2]
  def change
    change_table :order_details do |t|
      t.decimal "adjust_cost" ,precision: 10 , scale: 2, default: 0
    end
  end
end
