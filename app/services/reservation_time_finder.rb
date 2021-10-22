# frozen_string_literal: true

class ReservationTimeFinder

  include DateHelper

  attr_reader :reservation
#  delegate :order_detail, to: :reservation

  def initialize(reservation)
    @reservation = reservation
  end

  def actual_start_at

    od = OrderDetail.purchased_reservations
               .joins(:product)
               .joins_relay
               .where(product_id: @reservation.product_id)
               .where("actual_start_at <= ?", @reservation.reserve_start_at)
               .where("actual_end_at >= ?", @reservation.reserve_start_at)
               .readonly(false)

#    @conflict_reservtions = Reservation.where(product_id: @reservation.product.id)
#                            .where("actual_start_at <= ?", @reservation.reserve_start_at)
#                            .where("actual_end_at >= ?", @reservation.reserve_start_at)

    if od.present?
      #round_up_15min(Time.zone.now)
      od.first.reservation.actual_end_at
    else
      @reservation.reserve_start_at
    end
  end

end
