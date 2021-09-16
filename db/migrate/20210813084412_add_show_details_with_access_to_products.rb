class AddShowDetailsWithAccessToProducts < ActiveRecord::Migration[5.2]
  def change
    change_table :products do |t|
      t.boolean "show_details_with_access", default: false
  end
end
