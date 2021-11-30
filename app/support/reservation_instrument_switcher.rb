# frozen_string_literal: true

class ReservationInstrumentSwitcher

  attr_reader :reservation

  def initialize(reservation)
    @reservation = reservation
  end

  def switch_on!
    if relays_enabled?
      ActiveRecord::Base.transaction do
        begin
          if @reservation.start_reservation!
            instrument.instrument_statuses.create(is_on: true)
            raise(ActiveRecord::Rollback) unless switch_relay_on
          end
        end
      rescue => e
        raise e
        raise(ActiveRecord::Rollback)
      end
    else
      @reservation.start_reservation!
    end


    # raise relay_error_msg unless reservation.can_switch_instrument_on?
    # if switch_relay_on
    #   @reservation.start_reservation!
    # else
    #   raise relay_error_msg
    # end
    # instrument.instrument_statuses.create(is_on: true)
  end

  def switch_off!
    if relays_enabled?
      ActiveRecord::Base.transaction do
        begin
          if @reservation.end_reservation!
            instrument.instrument_statuses.create(is_on: false)
            raise(ActiveRecord::Rollback) if switch_relay_off
          end
        end
      rescue => e
        raise e
        raise(ActiveRecord::Rollback)
      end
    else
      @reservation.end_reservation!
    end

    # raise relay_error_msg unless reservation.can_switch_instrument_off?

    # if switch_relay_off == false
    #   @reservation.end_reservation!
    # else
    #   raise relay_error_msg
    # end
    # instrument.instrument_statuses.create(is_on: false)
  end

  private

  def switch_relay_off
    # if relays_enabled?
    relay.call_relay_user_info(@reservation.order_detail.order_number, @reservation.order_detail.user.full_name, @reservation.order_detail.user.username, @reservation.reserve_start_at.strftime('%d %b %Y %-l:%M %p'), @reservation.reserve_end_at.strftime('%d %b %Y %-l:%M %p'))
    relay.deactivate
    return relay.get_status
    # else
    #   false
    # end
  end

  def switch_relay_on
    # if relays_enabled?
    relay.call_relay_user_info(@reservation.order_detail.order_number, @reservation.order_detail.user.full_name, @reservation.order_detail.user.username, @reservation.reserve_start_at.strftime('%d %b %Y %-l:%M %p'), @reservation.reserve_end_at.strftime('%d %b %Y %-l:%M %p'))
    relay.activate
    return relay.get_status
    # else
    #   true
    # end
  end

  def relays_enabled?
    SettingsHelper.relays_enabled_for_reservation?
  end

  def instrument
    reservation.product
  end

  def relay
    instrument.relay
  end

  def relay_error_msg
    "An error was encountered while attempted to toggle the instrument. Please try again."
  end

end
