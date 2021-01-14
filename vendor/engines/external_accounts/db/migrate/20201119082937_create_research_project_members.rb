class CreateResearchProjectMembers < ActiveRecord::Migration[5.2]
  def change
    create_table :research_project_members, id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8"  do |t|
      t.references :research_project, type: :int, null: false, foreign_key: true
      t.string :username, null: false, limit: 255
      t.string :user_role, null: false, limit: 50
      t.boolean :is_left_project
      t.datetime :left_project_date
    end
  end
end
