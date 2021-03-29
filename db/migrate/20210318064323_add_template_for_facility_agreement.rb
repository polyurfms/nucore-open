class AddTemplateForFacilityAgreement < ActiveRecord::Migration[5.2]
  def change
    create_table :agreement_templates do |t|
      t.string :name, null: false, limit: 50
      t.string :description, null: false, limit: 5000
      t.datetime   :deleted_at
      t.integer    :deleted_by
      t.timestamps
    end
    
  end
end
