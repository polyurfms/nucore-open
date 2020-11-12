class CreateAgreementTable < ActiveRecord::Migration[5.2]
 def change
       create_table "user_agreements", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
            t.integer "user_id"
            t.boolean "accept", default: false, null: false
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
        end
 end
end
