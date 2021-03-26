class AddSupervisorToUser < ActiveRecord::Migration[5.2]
  def change
    change_table :users do |t|
      t.string "supervisor" ,limit: 100
      # t.boolean "is_academic", default: false
    end
  end
end
