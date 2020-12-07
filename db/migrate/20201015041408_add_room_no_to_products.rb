class AddRoomNoToProducts < ActiveRecord::Migration[5.2]
  def change
    change_table :products do |t|
      t.string :room_no
    end
  end
end
