class AddIdToProductAccessScheduleRules < ActiveRecord::Migration[5.2]
  def change
    add_column :product_access_schedule_rules, :id, :primary_key
  end
end
