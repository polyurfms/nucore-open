class CreateResearchProjects < ActiveRecord::Migration[5.2]
  def change
    create_table :research_projects, id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8"  do |t|
      t.string :pgms_project_id, limit: 20
      t.string :account_number, limit: 50
      t.datetime :expires_at
      t.string :project_title, null: false, limit: 1000
    end
  end
end
