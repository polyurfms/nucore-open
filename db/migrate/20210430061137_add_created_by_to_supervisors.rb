class AddCreatedByToSupervisors < ActiveRecord::Migration[5.2]
  def change

    change_table :supervisors do |t|
      t.integer :created_by
      t.integer :updated_by
    end
  end
end
