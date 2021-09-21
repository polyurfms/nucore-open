class UpdateUserInfoToSupervisor < ActiveRecord::Migration[5.2]
  def change
    add_column :supervisors, :net_id, :string, limit: 200, null: true
    add_column :supervisors, :dept_abbrev, :string, limit: 10, null: true
  end
end
