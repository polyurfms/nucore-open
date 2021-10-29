class AddStaffAssistenceToOrderDetails < ActiveRecord::Migration[5.2]
  def change
    change_table :order_details do |t|
      t.boolean :staff_assistance, default: false
    end
  end
end
