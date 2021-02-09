class CreateFoJournalRows < ActiveRecord::Migration[5.2]
  def change
    create_table :"fo_journal_rows" , id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
		t.integer "fo_journal_id", null: false
		t.string "source_name", limit: 25, null: false
		t.string "account_date", limit: 8, null: false
		t.string "currency_code", limit: 3, null: false
		t.string "actual_flag", limit: 1, null: false
		t.string "account_code", limit: 9, null: false
		t.decimal "debit_amt" ,precision: 10 , scale: 2, default: 0
		t.decimal "credit_amt",precision: 10 , scale: 2, default: 0
		t.string "system_code", limit: 2, null: false
		t.string "create_date_time", limit: 12, null: false
		t.string "ref_no", limit: 6, null: false
		t.string "description", limit: 240, null: false
		t.string "ecumbrance_type", limit: 30, null: false
	end
  end
end
