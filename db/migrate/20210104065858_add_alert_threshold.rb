class AddAlertThreshold < ActiveRecord::Migration[5.2]
  def change
    add_column :accounts, :alert_threshold, :decimal, precision: 10, scale: 2, default: 0
  end
end
