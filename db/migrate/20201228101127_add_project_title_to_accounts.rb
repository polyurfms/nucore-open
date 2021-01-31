class AddProjectTitleToAccounts < ActiveRecord::Migration[5.2]
  def change
    change_table :accounts do |t|
      t.string "project_title" ,limit: 1000
    end
  end
end
