class CreateAccountFreeBalances < ActiveRecord::Migration[5.2]
  def change
    create_view :account_free_balances
  end
end
