# frozen_string_literal: true

require "date"

class Reservation < ApplicationRecord

  acts_as_paranoid # soft deletes
  has_paper_trail

  include DateHelper
  include Reservations::DateSupport
  include Reservations::Validations
  include Reservations::Rendering
  include Reservations::RelaySupport
  include Reservations::MovingUp

  # Associations
  #####
  belongs_to :product
  belongs_to :instrument, foreign_key: :product_id
  belongs_to :order_detail, inverse_of: :reservation
  belongs_to :created_by, class_name: "User"
  has_one :order, through: :order_detail

  ## Virtual attributes
  #####

  # Represents a resevation time that is unavailable, but is not an admin reservation
  # Used by timeline view
  attr_accessor :blackout

  # used for overriding certain restrictions
  attr_accessor :reserved_by_admin

  # Used when we want to force the order to complete even if it doesn't meet the
  # requirements of order_completeable?, e.g. the reservation time isn't over yet.
  attr_accessor :force_completion

  attr_accessor :currDatetime

  attr_accessor :select_additional_price_policy

  # Delegations
  #####
  delegate :note, :note=, :ordered_on_behalf_of?, :complete?, :account, :order,
           :complete!, :price_policy, :reference_id, :reference_id=, to: :order_detail, allow_nil: true

  delegate :account, :in_cart?, :user, to: :order, allow_nil: true
  delegate :facility, to: :product, allow_nil: true
  delegate :lock_window, to: :product, prefix: true
  delegate :owner, to: :account, allow_nil: true

  def canceled?
    return false unless order_detail
    order_detail.canceled_at?
  end

  ## AR Hooks
  before_save :set_billable_minutes
  after_update :auto_save_order_detail, if: :order_detail

  # Scopes
  #####

  scope :admin_and_offline, -> { where(type: %w(AdminReservation OfflineReservation)) }
  scope :purchased, -> { joins(order_detail: :order).merge(Order.purchased) }

  def self.active
    not_canceled
      .user
      .where(orders: { state: ["purchased", nil] })
      .joins_order
  end

  def self.room_interface
    not_canceled
     .where("reserve_start_at >= :start AND reserve_end_at <= :end AND order_detail_id IS NOT NULL", start: Time.current.beginning_of_day, end: Time.current.end_of_day)
     .joins_facility
     .where(facilities: {room_interface_enabled: true})
     .joins(:product)
     .where("products.room_no is not null and products.room_no <> ''")
  end

  scope :ends_in_the_future, lambda {
    where(reserve_end_at: nil).or(where("reserve_end_at > ?", Time.current))
  }

  scope :ready_to_start, lambda {
    where("reserve_end_at >= ?", Time.current)
      .where("reserve_start_at <= ?", Time.current)
  }

  def self.joins_facility
    joins("LEFT JOIN order_details ON order_details.id = reservations.order_detail_id")
      .joins("LEFT JOIN orders ON orders.id = order_details.order_id")
        .joins("LEFT JOIN facilities ON facilities.id = orders.facility_id")
  end

  def self.joins_order
    joins("LEFT JOIN order_details ON order_details.id = reservations.order_detail_id")
      .joins("LEFT JOIN orders ON orders.id = order_details.order_id")
  end

  scope :not_canceled, -> { where(order_details: { canceled_at: nil }) } # dubious
  scope :not_started, -> { where(actual_start_at: nil) }
  scope :not_ended, -> { where(actual_end_at: nil) }

  def self.not_this_reservation(reservation)
    if reservation.id
      where("reservations.id <> ?", reservation.id)
    else
      all
    end
  end

  scope :ongoing, -> { not_ended.where("actual_start_at <= ?", Time.current) }

  scope :current_in_use, lambda {
    not_canceled
      .joins_order
      .ends_in_the_future
      .not_ended
      .where("reserve_start_at <= ? OR actual_start_at IS NOT NULL", Time.current)
      .where(orders: { state: [nil, :purchased] })
  }

  scope :current_and_upcoming_today, lambda {
    not_canceled
      .joins_order
      .ends_in_the_future
      .not_ended
      .where("reserve_start_at <= ?", Time.new.end_of_day)
      .where(orders: { state: [nil, :purchased]})
      .order(reserve_start_at: :asc)
  }

  def self.today
    for_date(Time.current)
  end

  def self.for_date(date)
    in_range(date.beginning_of_day, date.end_of_day)
  end

  def self.in_range(start_time, end_time)
    where("reserve_end_at >= ?", start_time)
      .where("reserve_start_at < ?", end_time)
  end

  def self.upcoming(t = Time.current)
    # If this is a named scope differences emerge between Oracle & MySQL on #reserve_end_at querying.
    # Eliminate by letting Rails filter by #reserve_end_at
    joins("LEFT JOIN order_details ON order_details.id = reservations.order_detail_id")
      .joins("LEFT JOIN orders ON orders.id = order_details.order_id")
      .not_canceled
      .where("orders.state" => [nil, "purchased"])
      .order(reserve_end_at: :asc)
      .to_a
      .delete_if { |reservation| reservation.reserve_end_at < t }
  end

  def select_additional_price_policy?
    @select_additional_price_policy
  end

  def self.overlapping(start_at, end_at)
    # remove millisecond precision from time
    tstart_at = Time.zone.parse(start_at.to_s)
    tend_at   = Time.zone.parse(end_at.to_s)

    where("((reserve_start_at <= :start AND reserve_end_at >= :end) OR
          (reserve_start_at >= :start AND reserve_end_at <= :end) OR
          (reserve_start_at <= :start AND reserve_end_at > :start) OR
          (reserve_start_at < :end AND reserve_end_at >= :end) OR
          (reserve_start_at = :start AND reserve_end_at = :end))",
          start: tstart_at, end: tend_at)
  end

  def self.relay_in_progress
    where("actual_start_at IS NOT NULL AND actual_end_at IS NULL")
  end

  def self.within_reserved_time
    where("reserve_start_at <= :now and reserve_end_at > :now", now: Time.current)
  end

  def self.upcoming_offline(start_at_limit)
    user
      .where(product_id: OfflineReservation.current.pluck(:product_id))
      .not_canceled
      .not_ended
      .merge(OrderDetail.purchased)
      .joins(:order_detail)
      .where(order_details: { state: %w(new inprocess), problem: false })
      .where("reserve_start_at <= ?", start_at_limit)
  end

  scope :user, -> { where(type: nil) }

  def self.for_timeline(date, instrument_ids)
    admin_and_offline_reservations = admin_and_offline.for_date(date).where(product_id: instrument_ids)
    purchased_reservations = purchased.for_date(date).where(product_id: instrument_ids)
    (admin_and_offline_reservations + purchased_reservations).sort_by(&:reserve_start_at)
  end

  # Instance Methods
  #####

  def end_at_required?
    true
  end

  # Is there enough information to move an associated order to complete/problem?
  def order_completable?
    force_completion || actual_end_at || reserve_end_at < Time.current
  end

  def force_dirty!
    # The actual attribute doesn't matter, we just need to make sure this object
    # is marked as ActiveModel::Dirty when this method is called.
    actual_start_at_will_change!
  end

  def start_reservation!

#comment kick out overage user
=begin
    # If there are any reservations running over their time on the shared schedule,
    # kick them over to the problem queue.
    product.schedule.products.flat_map(&:started_reservations).each do |reservation|
      # If we're in the grace period for this reservation, but the other reservation
      # has not finished its reserved time, this will fail and this reservation will
      # not start.
      #instead of sending to problem queue, end the unfinished reservation
      MoveToProblemQueue.move_skip_problem!(reservation.order_detail, user: reservation.user, cause: :reservation_started)
      #MoveToProblemQueue.move!(reservation.order_detail, user: reservation.user, cause: :reservation_started)

    end
=end

    unless product.schedule.products.flat_map(&:started_reservations).empty?
      # If we're in the grace period for this reservation, but the other reservation
      # has not finished its reserved time, this will fail and this reservation will
      # not start.

      #instead of sending to problem queue, end the unfinished reservation
      raise ValidatorError.new "Failed to start reservation. The equipment is currently in use."
      #reservation.end_reservation
      #MoveToProblemQueue.move!(reservation.order_detail, user: reservation.user, cause: :reservation_started)
    else
      @t = Time.current
      # check if pervious affect existing booking start
      at = ReservationTimeFinder.new(self).actual_start_at
      update!(card_start_at: @t ,actual_start_at: at)
    end
  end

=begin
  def round_to_15_minutes(t)
    @date = @t.to_date
    @hour = @t.hour
    @minutes = @t.sec > 0 ? @t.min + 1 : @t.min

    @new_minutes = ((@minutes/15.to_f).ceil) *15
    if @new_minutes == 60
      @new_hour = @hour + 1
      @new_minutes = 0
    else
      @new_hour = @hour
    end
    update!(actual_start_at: currDatetime?)
    # update!(actual_start_at: Time.current)
  end
=end

  def end_reservation!

    @t = Time.current

    @new_t = round_up_15min(@t)

    @end_diff = TimeRange.new(reserve_end_at, @new_t).duration_mins

    if reserve_end_at.to_datetime < @t && @end_diff < 15
      update!(card_end_at: @t ,actual_end_at: reserve_end_at)
    else
      # if reserve end at grace period
      if @t <= reserve_start_at
        update!(card_end_at: @t ,actual_end_at: reserve_start_at + 15.minutes)
      else
        update!(card_end_at: @t ,actual_end_at: @new_t)
      end
    end

    order_detail.complete!
  end

  def round_reservation_times
    interval = product.reserve_interval.minutes # Round to the nearest reservation interval
    self.reserve_start_at = time_ceil(reserve_start_at, interval) if reserve_start_at
    self.reserve_end_at   = time_ceil(reserve_end_at, interval) if reserve_end_at
    self
  end

  def assign_actuals_off_reserve
    self.actual_start_at ||= reserve_start_at
    self.actual_end_at   ||= reserve_end_at
  end

  def valid_as_user?(user)
    if user.operator_of?(product.facility)
      self.reserved_by_admin = true
      valid?
    else
      self.reserved_by_admin = false
      valid?(context: :user_purchase)
    end
  end

  def save_as_user(user)
    if user.operator_of?(product.facility)
      self.reserved_by_admin = true
      save
    else
      self.reserved_by_admin = false
      save(context: :user_purchase)
    end
  end

  def save_as_user!(user)
    raise ActiveRecord::RecordInvalid.new(self) unless save_as_user(user)
  end

  def offline?
    type == "OfflineReservation"
  end

  def admin?
    order.nil? && !blackout?
  end

  def admin_removable?
    true
  end

  def blackout?
    blackout.present?
  end

  def can_start_early?
    return false unless in_grace_period?
    # no other reservation ongoing; no res between now and reserve_start;

    Reservation
      .not_started
      .where("reserve_start_at > :now", now: Time.current)
      .where("reserve_start_at < :reserve_start_at", reserve_start_at: reserve_start_at)
      .where(product_id: product_id)
      .joins(:order_detail)
      .where("order_detail_id IS NULL OR order_details.state IN ('new', 'inprocess')")
      .none?
  end

  # can the CUSTOMER cancel the order
  def can_cancel?
    !canceled? && reserve_start_at > Time.current && actual_start_at.nil? && actual_end_at.nil?
  end

  def can_customer_edit?
    !canceled? && !complete? && (reserve_start_at_editable? || reserve_end_at_editable?)
  end

  def reserve_start_at_editable?
    before_lock_window? && !started?
  end

  def reserve_end_at_editable?
    Time.current <= reserve_end_at && extendable? && actual_end_at.blank?
  end

  def extendable?
    next_available = product.next_available_reservation(after: reserve_end_at, options: { ignore_cutoff: true })

    return false unless next_available

    current_end_at = reserve_end_at.change(sec: 0)
    next_start_at = next_available.reserve_start_at.change(sec: 0)

    current_end_at == next_start_at
  end

  def before_lock_window?
    Time.current < reserve_start_at - product_lock_window.hours
  end

  def inside_lock_window?
    !before_lock_window?
  end

  def admin_editable?
    new_record? || !canceled?
  end

  # TODO: does this need to be more robust?
  def can_edit_actuals?
    return false if order_detail.nil?
    complete?
  end

  def reservation_changed?
    reserve_start_at_changed? || reserve_end_at_changed?
  end

  def valid_before_purchase?
    satisfies_minimum_length? &&
      satisfies_maximum_length? &&
      allowed_in_schedule_rules? &&
      does_not_conflict_with_other_user_reservation? &&
      (reserved_by_admin || does_not_conflict_with_admin_reservation?)
  end

  def has_actuals?
    actual_start_at.present? && actual_end_at.present? && actual_end_at > actual_start_at
  end

  def started?
    actual_start_at.present?
  end

  def ongoing?
    !complete? && started? && actual_end_at.blank?
  end

  def requires_but_missing_actuals?
    !!(!canceled? && product.control_mechanism != Relay::CONTROL_MECHANISMS[:manual] && !has_actuals?) # TODO: refactor?
  end

  def problem_description_key
    :missing_actuals if requires_but_missing_actuals?
  end

  def locked?
    !(admin_editable? || can_edit_actuals?)
  end

  # Used in instrument utilization reports
  def quantity
    1
  end

  def update_billable_minutes
    update_column(:billable_minutes, calculated_billable_minutes)
  end

  private

  def auto_save_order_detail
    if (%w(actual_start_at actual_end_at reserve_start_at reserve_end_at) & saved_changes.keys).any?
      order_detail.save
    end
  end

  def in_grace_period?(at = Time.current)
    at = at.to_i
    grace_period_end = reserve_start_at.to_i
    grace_period_begin = (reserve_start_at - grace_period_duration).to_i

    # Compare int values, not timestamps. If you do the
    # latter fractions of a second can cause false positives.
    at >= grace_period_begin && at <= grace_period_end
  end

  def grace_period_duration
    SettingsHelper.setting("reservations.grace_period") || 5.minutes
  end

  def set_billable_minutes
    self.billable_minutes = calculated_billable_minutes
  end

  def currDatetime?
    @currDatetime = Time.current if @currDatetime.nil?
    @currDatetime
  end

  # FIXME: Temporary override to include reconciled orders, so we can backfill them
  def calculated_billable_minutes
    if (order_detail&.complete? || order_detail&.reconciled?) && order_detail&.canceled_at.blank? && price_policy.present?

      case price_policy.charge_for
      when InstrumentPricePolicy::CHARGE_FOR.fetch(:reservation)
        TimeRange.new(reserve_start_at, reserve_end_at).duration_mins
      when InstrumentPricePolicy::CHARGE_FOR.fetch(:usage)
        TimeRange.new(actual_start_at, actual_end_at).duration_mins
      when InstrumentPricePolicy::CHARGE_FOR.fetch(:overage)
        end_time = [reserve_end_at, actual_end_at].max
        TimeRange.new(reserve_start_at, end_time).duration_mins
      when InstrumentPricePolicy::CHARGE_FOR.fetch(:overage_penalty_and_end_early_discount)
        end_time = [reserve_end_at, actual_end_at].max
        TimeRange.new(reserve_start_at, end_time).duration_mins
      when InstrumentPricePolicy::CHARGE_FOR.fetch(:overage_penalty)
        end_time = [reserve_end_at, actual_end_at].max
        TimeRange.new(reserve_start_at, end_time).duration_mins
      end
    end
  end

end
