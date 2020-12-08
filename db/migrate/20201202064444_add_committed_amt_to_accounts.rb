class AddCommittedAmtToAccounts < ActiveRecord::Migration[5.2]
  def change
    change_table :accounts do |t|
      t.decimal "committed_amt" ,precision: 10 , scale: 2, default: 0
    end
  end
end
