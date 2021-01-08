class AddRemarksToFundingRequests < ActiveRecord::Migration[5.2]
  def change
    change_table :funding_requests do |t|
      t.string "remarks" ,limit: 100
    end
  end
end
