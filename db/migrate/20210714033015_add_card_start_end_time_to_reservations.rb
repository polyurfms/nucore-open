class AddCardStartEndTimeToReservations < ActiveRecord::Migration[5.2]
  def change
    change_table :reservations do |t|
      t.datetime "card_start_at"
      t.datetime "card_end_at"
    end
  end
end
