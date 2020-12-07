class CreateAccountTransactions < ActiveRecord::Migration[5.2]
  def change
    create_table "account_transactions", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
            t.integer "account_id" , null: false
			t.string "operation_type", limit: 50, null: false
			t.string "status" , limit: 50, null: false
            t.decimal "debit_amt",  precision: 10, scale: 2 , null: false
            t.decimal "credit_amt",  precision: 10, scale: 2 , null: false
			t.datetime :"created_at", null: false
        end
    end
end
