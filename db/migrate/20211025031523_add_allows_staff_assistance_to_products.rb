class AddAllowsStaffAssistanceToProducts < ActiveRecord::Migration[5.2]
  def change
    change_table :products do |t|
      t.boolean :allows_staff_assistance, default: false
    end
  end
end
