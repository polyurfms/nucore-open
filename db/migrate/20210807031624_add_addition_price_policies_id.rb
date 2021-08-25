class AddAdditionPricePoliciesId < ActiveRecord::Migration[4.2]
  def change
    
    add_column :order_details, :addition_price_policy_type, :string, null: true
    # add_column :order_details, :addition_price_policies_id, :integer, null: true
    # execute "ALTER TABLE order_details ADD CONSTRAINT addition_price_policies_FK FOREIGN KEY (addition_price_policies_id) REFERENCES addition_price_policies(id)"
  end
end
