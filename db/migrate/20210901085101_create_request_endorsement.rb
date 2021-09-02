class CreateRequestEndorsement < ActiveRecord::Migration[5.2]
    def self.up
      create_table :request_endorsements do |t|
        t.integer :user_id, null: false
        t.string     :supervisor,  null: false, limit: 50
        t.string :token, null: false
        t.boolean :is_accepted, null: true
        t.datetime   :deleted_at, null: true
        t.integer    :deleted_by, null: true
        t.integer    :created_by, null: false
        t.integer    :updated_by, null: false
        t.timestamps
      end
      # execute "ALTER TABLE request_endorsements add CONSTRAINT fk_supervisor_id FOREIGN KEY (supervisor_id) REFERENCES users (id)"
      execute "ALTER TABLE request_endorsements add CONSTRAINT fk_user_id FOREIGN KEY (user_id) REFERENCES users (id)"
    end
  
    def self.down
      drop_table :request_endorsements
    end
end
