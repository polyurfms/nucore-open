class AddAllowsAllocationToAccounts < ActiveRecord::Migration[5.2]
  def change
    change_table :accounts do |t|
      t.boolean "allows_allocation", default: false, null: false
    end
  end
end
