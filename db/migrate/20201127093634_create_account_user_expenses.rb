class CreateAccountUserExpenses < ActiveRecord::Migration[5.2]
  def change
    create_view :account_user_expenses
  end
end
