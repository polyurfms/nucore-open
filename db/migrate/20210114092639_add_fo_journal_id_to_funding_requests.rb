class AddFoJournalIdToFundingRequests < ActiveRecord::Migration[5.2]
  def change
    change_table :funding_requests do |t|
      t.integer :fo_journal_id
    end
  end
end
