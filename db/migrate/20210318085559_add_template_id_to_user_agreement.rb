class AddTemplateIdToUserAgreement < ActiveRecord::Migration[5.2]
  def up
    # change_table :user_agreements do |t|
    #   t.references :agreement_templates, foreign_key: true
    # end

    add_column :agreement_templates, :facility_id, :integer, after: :id
    add_foreign_key :agreement_templates, :facilities, name: "fk_agreement_templates_facilities"

    add_column :user_agreements, :facility_id, :integer, after: :id
    add_foreign_key :user_agreements, :facilities, name: "fk_user_agreements_facilities"
  end

  def down
    remove_foreign_key :agreement_templates, name: "fk_agreement_templates_facilities"
    remove_column :agreement_templates, :facility_id

    remove_foreign_key :user_agreements, name: "fk_user_agreements_facilities"
    remove_column :user_agreements, :facility_id
  end
end