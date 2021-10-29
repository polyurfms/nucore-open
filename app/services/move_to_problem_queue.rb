# frozen_string_literal: true

class MoveToProblemQueue

  include DateHelper

  def self.move!(order_detail, force: false, user: nil, cause:)
    new(order_detail, force: force, user: user, cause: cause).move!
  end

  def self.move_skip_problem!(order_detail, force: false, user: nil, cause:)
    new(order_detail, force: force, user: user, cause: cause).move_skip_problem!
  end

  def initialize(order_detail, force: false, user: nil, cause:)
    @order_detail = order_detail
    @force = force
    @user = user
    @cause = cause
  end

  def move!
    # Some scopes may accidentally try send already-complete orders to the queue.
    # This protects against sending duplicate emails to things already in the queue.
    return unless @order_detail.pending?

    @order_detail.time_data.force_completion = @force
    @order_detail.complete!
    LogEvent.log(@order_detail, :problem_queue, @user, metadata: {cause: @cause})

    # TODO: Can probably remove this at some point, but it's a safety check for now
    raise "Trying to move Ref. No.#{@order_detail} to problem queue, but it's not a problem" unless @order_detail.problem?
    if OrderDetails::ProblemResolutionPolicy.new(@order_detail).user_can_resolve?
      ProblemOrderMailer.notify_user_with_resolution_option(@order_detail).deliver_later
    else
      ProblemOrderMailer.notify_user(@order_detail).deliver_later
    end
  end

  def move_skip_problem!
    #when missing actual end time (end by the start of other reservation), set actual_end_at = now and end the reservaton
    return unless @order_detail.pending?

    @order_detail.time_data.force_completion = @force

    @t = Time.current

    @new_t = round_up_15min(@t)

    @end_diff = TimeRange.new(@order_detail.reservation.reserve_end_at, @new_t).duration_mins

    if @order_detail.reservation.reserve_end_at.to_datetime < @t && @end_diff < 15
      @order_detail.reservation.update!(card_end_at: @t ,actual_end_at: @order_detail.reservation.reserve_end_at)
    else
      @order_detail.reservation.update!(card_end_at: @t ,actual_end_at: @new_t)
    end

    @order_detail.complete!
    LogEvent.log(@order_detail, :problem_queue, @user, metadata: {cause: @cause})

  end

end
