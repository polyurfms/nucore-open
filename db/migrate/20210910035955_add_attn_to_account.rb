class AddAttnToAccount < ActiveRecord::Migration[5.2]
  def change
    change_table :accounts do |t|
      t.string :attention, limit: 255
    end
  end
end
