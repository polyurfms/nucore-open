class AddIsAcademicToSupervisors < ActiveRecord::Migration[5.2]
  def change
    change_table :supervisors do |t|
      t.boolean :is_academic
      t.remove :need_attention

    end
  end
end
