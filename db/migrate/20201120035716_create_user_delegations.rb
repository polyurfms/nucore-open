class CreateUserDelegations < ActiveRecord::Migration[5.2]
  def change
    create_table :user_delegations do |t|
      t.integer :delegator, null: false
      t.string :delegatee, null: false

      t.timestamps
    end
    
    add_index :user_delegations, [:delegator, :delegatee], unique: true
    add_foreign_key :user_delegations, :users, column: :delegator, primary_key: "id"
  end
end
