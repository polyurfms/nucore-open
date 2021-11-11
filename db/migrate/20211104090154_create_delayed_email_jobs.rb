class CreateDelayedEmailJobs < ActiveRecord::Migration[5.2]
  def change
    create_table :delayed_email_jobs do |t|
      t.integer :refer_id, null: false
      t.string :refer_name,  null: false, limit: 50
      t.datetime   :sent_at, null: true
      t.timestamps
    end
  end
end
