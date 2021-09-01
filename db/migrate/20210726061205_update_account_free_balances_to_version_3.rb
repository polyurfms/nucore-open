class UpdateAccountFreeBalancesToVersion3 < ActiveRecord::Migration[5.2]
  def change
    update_view :account_free_balances, version: 3, revert_to_version: 2
  end
end
