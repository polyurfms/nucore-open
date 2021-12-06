# frozen_string_literal: true

class EndNoShowReservation

  def perform
    order_details.find_each do |order_detail|
      order_detail.transaction do
        end_no_show_reservation(order_detail)
      end
    end
  end

  private

  def order_details
    purchased_expired_order_details_with_relay
  end

  def purchased_expired_order_details_with_relay
    OrderDetail.purchased_active_reservations
               .joins(:product)
               .joins_relay
               .where("reservations.reserve_end_at < ?", Time.zone.now)
               .where("actual_start_at is null and actual_end_at is null")
               .readonly(false)
  end

  def end_no_show_reservation(order_detail)
    #MoveToProblemQueue.move!(order_detail, cause: :auto_expire)
    if overlap_with_long_researvation?(order_detail.reservation)
      order_detail.overlapping_order_backdate_to_complete!
    else
      #complete no show record, charge reserve duration
      order_detail.backdate_to_complete!
    end

  rescue => e
    ActiveSupport::Notifications.instrument("background_error",
                                            exception: e, information: "Failed complete no show reservation order detail ##{order_detail}")
    raise ActiveRecord::Rollback
  end

  def overlap_with_long_researvation?(reservation)
    od = OrderDetail.purchased_reservations
               .joins(:product)
               .joins_relay
               .where(product_id: reservation.product_id)
               .where("actual_start_at <= ?", reservation.reserve_start_at)
               .where("actual_end_at >= ? or actual_end_at is null", reservation.reserve_start_at)
               .readonly(true)
     if od.present?
       true
     else
       false
     end
  end

end
