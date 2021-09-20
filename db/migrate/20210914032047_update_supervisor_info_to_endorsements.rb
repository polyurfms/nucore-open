class UpdateSupervisorInfoToEndorsements < ActiveRecord::Migration[5.2]
  def change
    add_column :request_endorsements, :first_name, :string, limit: 200, null: true
    add_column :request_endorsements, :last_name, :string, limit: 200, null: true
    add_column :request_endorsements, :email, :string, limit: 200, null: true
    add_column :request_endorsements, :dept_abbrev, :string, limit: 10, null: true
  end
end
