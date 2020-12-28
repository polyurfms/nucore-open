class CreateIntfResearchProjects < ActiveRecord::Migration[5.2]
  def change
    create_table :intf_research_projects, id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8"  do |t|
      t.string :account_number, limit: 50
      t.string :project_title, null: false, limit: 10000
    end
  end
end
