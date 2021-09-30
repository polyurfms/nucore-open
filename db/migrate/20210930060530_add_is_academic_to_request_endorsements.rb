class AddIsAcademicToRequestEndorsements < ActiveRecord::Migration[5.2]
  def change
    change_table :request_endorsements do |t|
      t.boolean :is_academic
    end
  end
end
