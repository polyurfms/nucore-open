class AddFoJournalIdToOrderDetails < ActiveRecord::Migration[5.2]
  def change
    change_table :order_details do |t|
      t.integer :fo_journal_id
    end
  end
end
