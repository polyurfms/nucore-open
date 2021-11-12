# frozen_string_literal: true

class ReviewEmailSender

  def run!
    facilities = Facility.all
    facilities.each do |facility|
      delay_job_list = get_delay_job_list("ReviewEmail", "OrderDetail", facility)
      send_email(delay_job_list, facility) if delay_job_list.count > 0
    end
  end

  private

  def get_delay_job_list(ref_type, ref_table, facility)
    DelayedEmailJob.where(sent_at: nil, ref_type: ref_type, ref_table: ref_table)
      .joins("INNER JOIN order_details ON order_details.id = delayed_email_jobs.ref_id")
      .joins("INNER JOIN orders on orders.id = order_details.order_id")
      .joins("INNER JOIN facilities on orders.facility_id = facilities.id")
      .where("facilities.id IN (?)", facility.id)
  end

  def send_email(delay_job_list, facility)
    list = Array.new

    delay_job_list.each do |job|
      list << job.ref_id.to_s
    end
    @order_detail_ids = ActionController::Parameters.new({"order_detail_ids" => list})

    #sender = NotificationSender.new(facility, params, false, true)
    @order_details = OrderDetail.for_facility(facility)
      .need_notification_without_reviewed_at
      .where_ids_in(list)
      .includes(:product, :order, :price_policy, :reservation)
    #if sender.perform_delay_review_email

    @account_ids_to_notify ||= @order_details.distinct.pluck(:account_id)

    if @account_ids_to_notify.present?
      AccountNotifier.new.delay.notify_accounts(@account_ids_to_notify, facility)
      update_delayed_email_job(delay_job_list)
      #sender.order_details.each do |order_detail|
      #  LogEvent.log(order_detail, :notify, 0)
      #end
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

  class AccountNotifier

    def notify_accounts(account_ids_to_notify, facility)
      notifications_hash(account_ids_to_notify).each do |user, accounts|
        Notifier.review_orders(user: user, accounts: accounts, facility: facility).deliver_now
      end
    end

    private

    # This builds a Hash of account Arrays, keyed by the user.
    # The users are the administrators (owners and business administrators)
    # of the given accounts.
    def notifications_hash(account_ids_to_notify)
      account_ids_to_notify.each_with_object({}) do |account_id, notifications|
        account = Account.find(account_id)
        account.administrators.each do |administrator|
          notifications[administrator] ||= []
          notifications[administrator] << account
        end
      end
    end

  end


end
