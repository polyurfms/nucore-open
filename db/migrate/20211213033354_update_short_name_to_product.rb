class UpdateShortNameToProduct < ActiveRecord::Migration[5.2]
  def change
    change_table :products do |t|
      t.string :abbreviation, limit: 255
    end
  end
end
