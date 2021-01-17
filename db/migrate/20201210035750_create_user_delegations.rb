class CreateUserDelegations < ActiveRecord::Migration[5.2]
  def change
    create_table :user_delegations do |t|
      t.integer :delegator, null: false
      t.string :delegatee, null: false

      t.datetime   :deleted_at, null: true
      t.integer    :deleted_by, null: true
      t.timestamps
    end
    
    add_index :user_delegations, [:delegator, :delegatee]
    add_foreign_key :user_delegations, :users, column: :delegator, primary_key: "id"
  end
end
