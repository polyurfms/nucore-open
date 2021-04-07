class UpdateAccountFreeBalancesToVersion2 < ActiveRecord::Migration[5.2]
  def change
    update_view :account_free_balances, version: 2, revert_to_version: 1
  end
end
