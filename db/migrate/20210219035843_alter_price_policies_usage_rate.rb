class AlterPricePoliciesUsageRate < ActiveRecord::Migration[5.2]
  def change
    
    def up
      change_column :price_policies, :usage_rate, precision: 12, scale: 6
    end

    def down
      change_column :price_policies, :usage_rate, precision: 12, scale: 6
    end
  end
end
