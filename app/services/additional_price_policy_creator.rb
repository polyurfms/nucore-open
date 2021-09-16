# frozen_string_literal: true

class AdditionalPricePolicyCreator

  def create_additional_price_policy_in_price_policy(product, start_date, expire_date, action, current_user, price_policy_date)
    @price_policies = PricePolicy.where("DATE_FORMAT(start_date,'%Y-%m-%d %H:%i:%s') = DATE_FORMAT(:start,'%Y-%m-%d %H:%i:%s')  AND DATE_FORMAT(expire_date,'%Y-%m-%d %H:%i:%s') = DATE_FORMAT(:expire,'%Y-%m-%d %H:%i:%s') ", start: start_date, expire: expire_date) if action.eql?("create")
    @current_price_policies = product.price_policies.current_and_newest if action.eql?("create")
    create(@current_price_policies, current_user, @price_policies, product) if action.eql?("create")

    @price_policies = PricePolicy.where("start_date <= :now AND expire_date > :now", now: price_policy_date) if action.eql?("delete")
    delete(@price_policies, current_user) if action.eql?("delete")
  end

  def create(current_price_policies, current_user, price_policies, product)

    @new_additional_price_policies = Array.new

    @mapping= {}
    @mapping = price_policies.each_with_object({}) do |price_policy, names|
      names[price_policy.price_group_id] = price_policy.id
    end

    @map_group_id = {}

    array_price_policy_id = Array.new
    @map_policy_group_with_cost = {}

#    unless @new_additional_price_policies.nil?
    ActiveRecord::Base.transaction do

      @existing_additional_price_groups = AdditionalPriceGroup.joins(:additional_price_policies).where("additional_price_policies.price_policy_id=? and additional_price_groups.deleted_at is null",current_price_policies.first.id)

      @existing_additional_price_groups.each do |existing_group|
        new_group = existing_group.dup
        new_group.save
        @map_group_id.store(existing_group.id, new_group.id)
      end

      price_policies.each do |new_price_policy|
        @current_policy = current_price_policies.detect{|p| p["price_group_id"]==new_price_policy.price_group_id}
        if @current_policy.nil?
          @map_group_id.each do |key, value|

            new_additional_price_policy = AdditionalPricePolicy.new
            new_additional_price_policy.price_policy_id = new_price_policy.id
            new_additional_price_policy.cost = 0
            new_additional_price_policy.additional_price_group_id = value
            new_additional_price_policy.created_at = Time.zone.now
            new_additional_price_policy.updated_at = Time.zone.now
            new_additional_price_policy.created_by = current_user
            new_additional_price_policy.save
          end
        else
          @additional_price_policies = AdditionalPricePolicy.where(price_policy_id: @current_policy.id, deleted_at: nil)
          @additional_price_policies.each do |additional_price_policy|
            new_additional_price_policy(additional_price_policy, current_user, new_price_policy.id).save!
          end
          @new_additional_price_policies.all?(&:save) || raise(ActiveRecord::Rollback)
        end
      end
#      end
    end
  end

  def new_additional_price_policy(additional_price_policy, current_user, price_policy_id)
    @date = Time.zone.now

#    @new_price_group = @new_additional_price_groups.find{|k| k[:name] == additional_price_policy.additional_price_group.name}

#    new_price_group_id = @new_price_group.id

    "AdditionalPricePolicy".constantize.new(
      #name: additional_price_policy.name,
      cost: additional_price_policy.cost,
      price_policy_id: price_policy_id,
      created_at: @date,
      updated_at: @date,
      created_by: current_user,
      additional_price_group_id: @map_group_id[additional_price_policy.additional_price_group_id]
    )
  end

  def delete(price_policies, current_user)
    delete_group_id = Array.new
    ActiveRecord::Base.transaction do
      price_policies.each do |price_policy|
        if price_policy.additional_price_policy.length > 0
          price_policy.additional_price_policy.each do |additional_price_policy|
            @date = Time.zone.now
            delete_group_id.push(additional_price_policy.additional_price_group_id)
            @a = AdditionalPricePolicy.find(additional_price_policy.id.to_i)
            unless @a.destroy
              raise(ActiveRecord::Rollback)
            end
          end
        end
      end
    end
    AdditionalPriceGroup.where(id: delete_group_id.uniq).delete_all
  end
end
