# frozen_string_literal: true

class AdditionPricePolicyCreator

  def create_addition_price_policy_in_price_policy(product, start_date, expire_date, action, current_user, price_policy_date)
    @price_policies = PricePolicy.where("DATE_FORMAT(start_date,'%Y-%m-%d %H:%i:%s') = DATE_FORMAT(:start,'%Y-%m-%d %H:%i:%s')  AND DATE_FORMAT(expire_date,'%Y-%m-%d %H:%i:%s') = DATE_FORMAT(:expire,'%Y-%m-%d %H:%i:%s') ", start: start_date, expire: expire_date) if action.eql?("create")
    @current_price_policies = product.price_policies.current_and_newest if action.eql?("create")
    create(@current_price_policies, current_user, @price_policies) if action.eql?("create")

    @price_policies = PricePolicy.where("start_date <= :now AND expire_date > :now", now: price_policy_date) if action.eql?("delete")
    delete(@price_policies, current_user) if action.eql?("delete")
  end

  def create(current_price_policies, current_user, price_policies)

    @new_addition_price_policies = Array.new

    @mapping= {}
    @mapping = price_policies.each_with_object({}) do |price_policy, names|
      names[price_policy.price_group_id] = price_policy.id
    end

    current_price_policies.each do |current_price_policy|
      # @addition_price_policies = AdditionPricePolicy.where("price_policy_id = :id AND deleted_at IS NULL", id: current_price_policy.id)
      @addition_price_policies = AdditionPricePolicy.get_addition_price_policy_list(current_price_policy.id)
      @price_policy_id = @mapping[current_price_policy.price_group_id]

      unless @addition_price_policies.nil?
        @addition_price_policies.each do |addition_price_policy|
          @new_addition_price_policies << new_addition_price_policy(addition_price_policy, current_user, @price_policy_id) if addition_price_policy.deleted_at.nil? || addition_price_policy.deleted_at.blank?
        end
      end
    end

    unless @new_addition_price_policies.nil?
      ActiveRecord::Base.transaction do
        @new_addition_price_policies.all?(&:save) || raise(ActiveRecord::Rollback)
      end
    end
  end

  def new_addition_price_policy(addition_price_policy, current_user, price_policy_id)
    @date = Time.zone.now

    "AdditionPricePolicy".constantize.new(
      name: addition_price_policy.name,
      cost: addition_price_policy.cost,
      price_policy_id: price_policy_id,
      created_at: @date,
      updated_at: @date,
      created_by: current_user
    )
  end

  def delete(price_policies, current_user)
    ActiveRecord::Base.transaction do
      price_policies.each do |price_policy|
        if price_policy.addition_price_policy.length > 0
          price_policy.addition_price_policy.each do |addition_price_policy|
            @date = Time.zone.now
            @a = AdditionPricePolicy.find(addition_price_policy.id.to_i)
            unless @a.destroy
              raise(ActiveRecord::Rollback)
            end
          end
        end
      end
    end
  end
end
