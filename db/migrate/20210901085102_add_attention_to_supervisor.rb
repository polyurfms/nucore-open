class AddAttentionToSupervisor < ActiveRecord::Migration[5.2]
  def change
    add_column :supervisors, :need_attention, :boolean, default: false
  end
end
