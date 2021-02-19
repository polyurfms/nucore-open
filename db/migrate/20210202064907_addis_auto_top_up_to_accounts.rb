class AddisAutoTopUpToAccounts < ActiveRecord::Migration[5.2]
  def change
    change_table :accounts do |t|
      t.boolean "is_auto_top_up", default: false, null: false
    end
  end
end
