class CreateAdditionPricePolicies < ActiveRecord::Migration[4.2]
	def self.up
		create_table :addition_price_policies do |t|
			t.string :name, null: false
			t.decimal :cost , precision: 13, scale: 2, null: false
			t.integer    :price_policy_id, null: false
			t.integer    :created_by, null: false
			t.datetime   :deleted_at, null: true
			t.integer    :deleted_by, null: true
			t.datetime   :created_at, null: true
			t.datetime   :updated_at, null: true
		end
		execute "ALTER TABLE addition_price_policies add CONSTRAINT fk_price_policy_id FOREIGN KEY (price_policy_id) REFERENCES price_policies (id)"
	end

	def self.down
		drop_table :addition_price_policies
	end
end
