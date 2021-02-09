class CreatePaymentSourceRequests < ActiveRecord::Migration[4.2]
  def up
    create_table :payment_source_requests do |t|
      
      t.references :user, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :created_by, null: false
      t.string :updated_by, null: false
      t.timestamps null: false
    end
  end

  def down
    drop_table :payment_source_requests
  end
end
