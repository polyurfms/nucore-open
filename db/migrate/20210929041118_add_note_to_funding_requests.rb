class AddNoteToFundingRequests < ActiveRecord::Migration[5.2]
  def change
    change_table :funding_requests do |t|
      t.string :note, limit: 200   
    end
  end
end
