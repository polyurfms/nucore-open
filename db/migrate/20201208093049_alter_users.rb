class AlterUsers < ActiveRecord::Migration[5.2]
  def change
    change_table :users do |t|
      t.string "user_type" , limit: 20
      t.string "dept_abbrev", limit: 10
    end
  end
end
