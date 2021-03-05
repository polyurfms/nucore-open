class AddDeptAbbrevToOrders < ActiveRecord::Migration[5.2]
  def change
    change_table :orders do |t|
      t.string "dept_abbrev", limit: 10
    end
  end
end

