class AddAdditionalPricePolicyNameToOrderDetails < ActiveRecord::Migration[4.2]
  def change

    add_column :order_details, :additional_price_group_id, :string, null: true
    # add_column :order_details, :additional_price_policies_id, :integer, null: true
    # execute "ALTER TABLE order_details ADD CONSTRAINT additional_price_policies_FK FOREIGN KEY (additional_price_policies_id) REFERENCES additional_price_policies(id)"
  end
end
