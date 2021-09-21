# frozen_string_literal: true

module PricePolicies

  class TimeBasedPriceCalculator

    attr_reader :price_policy

    delegate :usage_rate, :usage_subsidy, :minimum_cost, :minimum_cost_subsidy, :maximum_cost,
             :product, :additional_price_policy, to: :price_policy

    def initialize(price_policy)
      @price_policy = price_policy
    end

    def calculate(start_at, end_at, type)
      return if start_at > end_at
      duration_mins = TimeRange.new(start_at, end_at).duration_mins
      discount_multiplier = calculate_discount(start_at, end_at)
      if (!maximum_cost.nil? && maximum_cost > 0)
        cost_and_subsidy_with_max(start_at, end_at, discount_multiplier, type)
      else
        cost_and_subsidy(duration_mins, discount_multiplier, type)
      end
    end

    def calculate_overage_penalty_and_end_early_discount(reserve_start, reserve_end, start_at, end_at)
      return if start_at > end_at
      reserve_duration = TimeRange.new(reserve_start, reserve_end).duration_mins
      duration_mins = TimeRange.new(start_at, end_at).duration_mins
      discount_multiplier = calculate_discount(start_at, end_at)
      if (!maximum_cost.nil? && maximum_cost > 0)
        cost_and_subsidy_with_max(start_at, end_at, discount_multiplier)
      else
        cost_and_subsidy_with_penalty_and_discount(reserve_duration, duration_mins, discount_multiplier)
      end
    end

    def calculate_overage_penalty(reserve_start, reserve_end, start_at, end_at)
      return if start_at > end_at
      reserve_duration = TimeRange.new(reserve_start, reserve_end).duration_mins
      duration_mins = TimeRange.new(start_at, end_at).duration_mins
      discount_multiplier = calculate_discount(start_at, end_at)
      if (!maximum_cost.nil? && maximum_cost > 0)
        cost_and_subsidy_with_max(start_at, end_at, discount_multiplier)
      else
        cost_and_subsidy_with_penalty(reserve_duration, duration_mins, discount_multiplier)
      end
    end

    def calculate_discount(start_at, end_at)
      discount = product.schedule_rules.to_a.sum do |sr|
        sr.discount_for(start_at, end_at)
      end

      1 - (discount / 100)
    end

    private

    def cost_and_subsidy(duration_mins, discount_multiplier, type="")
      addition_cost = 0;

      unless additional_price_policy.nil? && type.eql?("")
        additional_price_policy.each do |ad|
          addition_cost = ad.cost/60 if ad.additional_price_group_id.eql?(type)
        end
      end
      costs = { cost: duration_mins * (usage_rate + addition_cost) * discount_multiplier }

      if costs[:cost] < minimum_cost.to_f
        { cost: minimum_cost, subsidy: minimum_cost_subsidy }
      else
        costs.merge(subsidy: duration_mins * usage_subsidy * discount_multiplier)
      end
    end

    def cost_and_subsidy_with_penalty_and_discount(reserve_duration, actual_duration, discount_multiplier)

      # actual larger than reserve, charge penalty
      if actual_duration >= reserve_duration

        if actual_duration <= reserve_duration + 15
          normal_duration = actual_duration
          penalty_duration = 0
        else
          normal_duration = reserve_duration + 15
          penalty_duration = actual_duration - normal_duration
        end

        normal_cost = normal_duration * usage_rate * discount_multiplier
        penalty_cost = penalty_duration * usage_rate * 1.5 * discount_multiplier

        costs = { cost: normal_cost + penalty_cost, penalty: penalty_cost }

        if costs[:cost] < minimum_cost.to_f
          { cost: minimum_cost, subsidy: minimum_cost_subsidy }
        else
          costs.merge(subsidy: normal_duration * usage_subsidy * discount_multiplier)
        end
      else #actual smaller than reserve, give discount
        normal_duration = actual_duration
        discount_duration = reserve_duration - normal_duration

        normal_cost = normal_duration * usage_rate * discount_multiplier
        discount_cost = discount_duration * usage_rate * discount_multiplier * 0.75

        costs = {cost: normal_cost + discount_cost, early_end_discount: discount_cost }

        if costs[:cost] < minimum_cost.to_f
          { cost: minimum_cost, subsidy: minimum_cost_subsidy}
        else
          costs.merge(subsidy: normal_duration * usage_subsidy * discount_multiplier)
        end

      end
    end

    def cost_and_subsidy_with_penalty(reserve_duration, actual_duration, discount_multiplier)
      # actual larger than reserve, charge penalty
      if actual_duration >= reserve_duration

        if actual_duration <= reserve_duration + 15
          normal_duration = actual_duration
          penalty_duration = 0
        else
          normal_duration = reserve_duration + 15
          penalty_duration = actual_duration - normal_duration
        end

        normal_cost = normal_duration * usage_rate * discount_multiplier
        penalty_cost = penalty_duration * usage_rate * 1.5 * discount_multiplier

        costs = { cost: normal_cost + penalty_cost, penalty: penalty_cost }

        if costs[:cost] < minimum_cost.to_f
          { cost: minimum_cost, subsidy: minimum_cost_subsidy }
        else
          costs.merge(subsidy: normal_duration * usage_subsidy * discount_multiplier)
        end
      else #actual smaller than reserve, no discount
        normal_duration = reserve_duration

        normal_cost = normal_duration * usage_rate * discount_multiplier

        costs = {cost: normal_cost}

        if costs[:cost] < minimum_cost.to_f
          { cost: minimum_cost, subsidy: minimum_cost_subsidy }
        else
          costs.merge(subsidy: normal_duration * usage_subsidy * discount_multiplier)
        end

      end
    end

    # Contain maximum cost
    def cost_and_subsidy_with_max(start_at, end_at, discount_multiplier, type="")
      result = 0.0

      addition_cost = 0;
      unless additional_price_policy.nil? && type.eql?("")
        additional_price_policy.each do |ad|
          addition_cost = ad.cost/60 if ad.additional_price_group_id.eql?(type)
        end
      end

      count_day = Date.parse(end_at.strftime("%Y-%m-%d")) - Date.parse(start_at.strftime("%Y-%m-%d"))
      # discount_multiplier = calculate_discount(start_at, end_at)
      total_duration_mins = 0

      case
      when count_day == 0
        # one day
        duration_mins = TimeRange.new(start_at, end_at).duration_mins
        result = over_maximum_cost(duration_mins, (usage_rate + addition_cost), 0)
      when count_day == 1
        # two day
        # Add "+ 1" for 23:59:59(end_of_day) + 1 secorc
        # First date
        duration_mins = TimeRange.new(start_at, start_at.end_of_day).duration_mins
        total_duration_mins = duration_mins + 1
        # result = over_maximum_cost(duration_mins, usage_rate, 0)
        result = over_maximum_cost(duration_mins + 1, (usage_rate + addition_cost), 0)

        # Last date
        # duration_mins = TimeRange.new(end_at, end_at.end_of_day).duration_mins
        duration_mins = TimeRange.new(end_at.beginning_of_day, end_at).duration_mins
        total_duration_mins = total_duration_mins + duration_mins if end_at.beginning_of_day != end_at
        result = result + over_maximum_cost(duration_mins, (usage_rate + addition_cost), 0) if end_at.beginning_of_day != end_at
      else
        # more than two day
        # Add "+ 1" for 23:59:59(end_of_day) + 1 secorc
        # First date
        duration_mins = TimeRange.new(start_at, start_at.end_of_day).duration_mins

        total_duration_mins = duration_mins + 1
        # result = over_maximum_cost(duration_mins, usage_rate, 0)
        result = over_maximum_cost(duration_mins + 1, (usage_rate + addition_cost), 0)

        # Last date
        duration_mins = TimeRange.new(end_at.beginning_of_day, end_at).duration_mins
        total_duration_mins = total_duration_mins + duration_mins if end_at.beginning_of_day != end_at
        # duration_mins = TimeRange.new(end_at, end_at.end_of_day).duration_mins
        result = result + over_maximum_cost(duration_mins, (usage_rate + addition_cost), 0) if end_at.beginning_of_day != end_at
        # Other date (60mins *24hr) = 1440
        result = result + over_maximum_cost(1440, (usage_rate + addition_cost), count_day - 1)
        total_duration_mins = total_duration_mins + (1440 * (count_day - 1))
      end

      costs = { cost: result * discount_multiplier }

      if costs[:cost] < minimum_cost.to_f
        { cost: minimum_cost, subsidy: minimum_cost_subsidy }
      else
        # costs.merge(subsidy: duration_mins * usage_subsidy * discount_multiplier)
        costs.merge(subsidy: total_duration_mins * usage_subsidy * discount_multiplier)
      end

    end

    def over_maximum_cost(in_mins, usage_rate, in_days)
      result = maximum_cost.to_f

      unless (maximum_cost.to_f < in_mins * usage_rate)
        result = in_mins * usage_rate
      end

      unless in_days < 2
        result = result * in_days
      end

      return result
    end

  end

end
