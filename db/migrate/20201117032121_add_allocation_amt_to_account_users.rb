class AddAllocationAmtToAccountUsers < ActiveRecord::Migration[5.2]
  def change
    change_table :account_users do |t|
      t.decimal "allocation_amt" ,precision: 10 , scale: 2
    end
  end
end
