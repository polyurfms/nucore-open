class AddPhoneToUsers < ActiveRecord::Migration[5.2]
  def change
    change_table :users do |t|
      t.string :phone, limit: 20
    end
  end
end
