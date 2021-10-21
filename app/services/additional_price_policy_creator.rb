# frozen_string_literal: true

class AdditionalPricePolicyCreator

  include DateHelper
  def create_additional_price_policy_in_price_policy(product, start_date, expire_date, action, current_user, price_policy_date)

    if action.eql?("delete")
      
      @price_policies = Array.new
      search_price_policies = PricePolicy.where("start_date <= :now AND expire_date > :now", now: price_policy_date.to_datetime)
      
      search_price_policies.each do |price_policy|
        @price_policies << price_policy if human_date(price_policy.start_date)  == human_date(price_policy_date.to_datetime)
      end
      # @price_policies = PricePolicy.where("DATE_FORMAT(start_date,'%Y-%m-%d %H:%i:%s') <= DATE_FORMAT(:now,'%Y-%m-%d %H:%i:%s') AND DATE_FORMAT(expire_date,'%Y-%m-%d %H:%i:%s') > DATE_FORMAT(:now,'%Y-%m-%d %H:%i:%s')", now: price_policy_date)
      delete(@price_policies, current_user)
    end

    if action.eql?("create")
      @price_policies = PricePolicy.where("DATE_FORMAT(start_date,'%Y-%m-%d %H:%i:%s') = DATE_FORMAT(:start,'%Y-%m-%d %H:%i:%s')  AND DATE_FORMAT(expire_date,'%Y-%m-%d %H:%i:%s') = DATE_FORMAT(:expire,'%Y-%m-%d %H:%i:%s') ", start: start_date, expire: expire_date)
      @current_price_policies = product.price_policies.current_and_newest
      create(@current_price_policies, current_user, @price_policies, product) 
    end
  end

  def create(current_price_policies, current_user, price_policies, product)

#    @new_additional_price_policies = Array.new
    # @mapping= {}
    # @mapping = price_policies.each_with_object({}) do |price_policy, names|
    #   names[price_policy.price_group_id] = price_policy.id
    # end
    is_created = AdditionalPricePolicy.joins("INNER JOIN price_policies on price_policies.id = additional_price_policies.price_policy_id").where("price_policy_id IN (?)", get_price_policy_id(price_policies)).where("deleted_at IS NULL").count > 0 ? true : false

#   @test = AdditionalPriceGroup.select_additional_price_groups(product.id)
    @existing_additional_price_groups = AdditionalPriceGroup.joins("INNER JOIN additional_price_policies on additional_price_policies.additional_price_group_id = additional_price_groups.id").joins("INNER JOIN price_policies on price_policies.id = additional_price_policies.price_policy_id").where("price_policy_id IN (?) AND additional_price_policies.deleted_at IS NULL", get_price_policy_id(current_price_policies)).uniq unless is_created

    # @existing_additional_price_groups = AdditionalPriceGroup.select_additional_price_groups(product.id) unless is_created
    @existing_additional_price_groups = AdditionalPriceGroup.joins("INNER JOIN additional_price_policies on additional_price_policies.additional_price_group_id = additional_price_groups.id").joins("INNER JOIN price_policies on price_policies.id = additional_price_policies.price_policy_id").where("price_policy_id IN (?) AND additional_price_policies.deleted_at IS NULL", get_price_policy_id(price_policies)).uniq if is_created
#    @map_group_id = {}
#    unless @new_additional_price_policies.nil?
    ActiveRecord::Base.transaction do

#      @existing_additional_price_groups.each do |existing_group|
#        @map_group_id.store(existing_group.id, new_group.id)
#      end
      price_policies.each do |new_price_policy|
        @created_addition_price_policies = AdditionalPricePolicy.where(price_policy_id: new_price_policy.id, deleted_at: nil)
        created_price_policies_id = Array.new
        @created_addition_price_policies.each do |p|
          created_price_policies_id << p.price_policy_id unless created_price_policies_id.include?(p.price_policy_id)
        end
        @current_policy = current_price_policies.detect{|p| p["price_group_id"]==new_price_policy.price_group_id}

        if @current_policy.nil?
          
          unless created_price_policies_id.include?(new_price_policy.id)
            
            @existing_additional_price_groups.each do |group|
              new_additional_price_policy = AdditionalPricePolicy.new
              new_additional_price_policy.price_policy_id = new_price_policy.id
              new_additional_price_policy.cost = 0
              new_additional_price_policy.additional_price_group_id = group.id
              new_additional_price_policy.created_at = Time.zone.now
              new_additional_price_policy.updated_at = Time.zone.now
              new_additional_price_policy.created_by = current_user
              new_additional_price_policy.save
            end
          end
         
        else
          @additional_price_policies = AdditionalPricePolicy.where(price_policy_id: @current_policy.id, deleted_at: nil)
          if @additional_price_policies.count > 0
            
            @additional_price_policies.each do |additional_price_policy|
              new_additional_price_policy(additional_price_policy, current_user, new_price_policy.id).save! unless created_price_policies_id.include?(new_price_policy.id)
            end
          else
            
            @existing_additional_price_groups.each do |group|
              new_additional_price_policy = AdditionalPricePolicy.new
              new_additional_price_policy.price_policy_id = new_price_policy.id
              new_additional_price_policy.cost = 0
              new_additional_price_policy.additional_price_group_id = group.id
              new_additional_price_policy.created_at = Time.zone.now
              new_additional_price_policy.updated_at = Time.zone.now
              new_additional_price_policy.created_by = current_user
              new_additional_price_policy.save
            end
          end
          
        end
      end

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
      additional_price_group_id: additional_price_policy.additional_price_group_id
    )
  end

  def get_price_policy_id(price_policies)
    search_id = Array.new
    price_policies.each do |p| 
      search_id << p.id if p.can_purchase
    end
    return search_id
  end

  def delete(price_policies, current_user)
    #delete_group_id = Array.new
    ActiveRecord::Base.transaction do
      price_policies.each do |price_policy|
        if price_policy.additional_price_policy.length > 0
          price_policy.additional_price_policy.each do |additional_price_policy|
            @date = Time.zone.now
            #delete_group_id.push(additional_price_policy.additional_price_group_id)
            @a = AdditionalPricePolicy.find(additional_price_policy.id.to_i)
            unless @a.destroy
              raise(ActiveRecord::Rollback)
            end
          end
        end
      end
    end
    #AdditionalPriceGroup.where(id: delete_group_id.uniq).delete_all
  end
end
