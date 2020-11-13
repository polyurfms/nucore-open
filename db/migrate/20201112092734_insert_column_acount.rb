class InsertColumnAcount < ActiveRecord::Migration[5.2]
  def change
    change_table :accounts do |t|
      t.boolean "allow_allocation", default: false, null: false
    end
  end
end
