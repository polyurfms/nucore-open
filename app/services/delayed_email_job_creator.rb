# frozen_string_literal: true

class DelayedEmailJobCreator
  def run!
    facilities = Facility.all
    facilities.each do |facility|
      delay_job_list = get_delay_job_list("OrderDetail", facility)
      send_email(delay_job_list, facility) if delay_job_list.count > 0      
    end
  end

  private
  
  def get_delay_job_list(refer_name, facility)
    DelayedEmailJob.where(sent_at: nil, refer_name: refer_name)
      .joins("INNER JOIN order_details ON order_details.id = delayed_email_jobs.refer_id")
      .joins("INNER JOIN orders on orders.id = order_details.order_id")
      .joins("INNER JOIN facilities on orders.facility_id = facilities.id")
      .where("facilities.id IN (?)", facility.id)
  end

  def send_email(delay_job_list, facility)
    list = Array.new
    
    delay_job_list.each do |job|
      list << job.refer_id.to_s
    end
    params = ActionController::Parameters.new({"order_detail_ids" => list})
    sender = NotificationSender.new(facility, params, false, true)
    
    if sender.perform
      update_delayed_email_job(delay_job_list)
      sender.order_details.each do |order_detail|
        LogEvent.log(order_detail, :notify, 0)
      end
    end
  end  

  def update_delayed_email_job(delay_job_list)
    now = Time.zone.now 
      ActiveRecord::Base.transaction do
        begin
          delay_job_list.each do |email|
            email.sent_at = now
            email.save || raise(ActiveRecord::Rollback)
          end
        end
      end
  end
end
  