class ReviewEmailCreator

  attr_reader :order_details

  def initialize(order_details)
    @order_details = order_details
  end

  def save
    now = Time.zone.now
    ActiveRecord::Base.transaction do
      begin
        @order_details.each do |od|
          delay_job = DelayedEmailJob.new
          delay_job.ref_type = "ReviewEmail"
          delay_job.ref_id = od.id
          delay_job.ref_table = od.class.name
          delay_job.created_at = now
          delay_job.updated_at = now

          delay_job.save || raise(ActiveRecord::Rollback)
        end
      end
    rescue => e
      ActiveSupport::Notifications.instrument("background_error",
        exception: e, information: "Failed to send notification")
      raise ActiveRecord::Rollback
    end
  end



end
