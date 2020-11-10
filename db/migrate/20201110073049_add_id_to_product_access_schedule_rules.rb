class AddIdToProductAccessScheduleRules < ActiveRecord::Migration[5.2]
  def change
    add_column :product_access_schedule_rules, :id, :primary_key

    if Nucore::Database.mysql?
      execute "ALTER TABLE product_access_schedule_rules AUTO_INCREMENT = 1"
    end
  end
end
