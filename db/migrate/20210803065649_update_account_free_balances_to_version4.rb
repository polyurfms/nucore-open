class UpdateAccountFreeBalancesToVersion4 < ActiveRecord::Migration[5.2]
  def change
    update_view :account_free_balances, version: 4, revert_to_version: 3
  end
end
