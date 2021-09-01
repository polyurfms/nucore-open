class AddSessionMinsToProducts < ActiveRecord::Migration[5.2]
  def change
    add_column :products, :session_mins, :int, default: 0
  end
end
