class CreateDelayedEmailJobs < ActiveRecord::Migration[5.2]
  def change
    create_table :delayed_email_jobs do |t|
      t.string :ref_type, null: false
      t.integer :ref_id, null: false
      t.string :ref_table,  null: false, limit: 50
      t.datetime   :sent_at, null: true
      t.timestamps
    end
  end
end
