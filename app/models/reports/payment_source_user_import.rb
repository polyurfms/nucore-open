# frozen_string_literal: true

require "csv"

class Reports::PaymentSourceUserImport
    REQUIRED_HEADERS = [
      "Netid",
      "Quota",
    ]

    
  def initialize(payment_source_user_import, account, session_user)
    @account = account
    @payment_source_user_import = payment_source_user_import
    @error_list ||= []
    @session_user = session_user
  end

  def import(type)
    validate_file_type!
    insert_payment_source_user! if type == "Insert"
    update_payment_source_user! if type == "Update"
  end

  def export!
    attributes = %w{Netid	Quota} 
    
    @account_users ||= AccountUser.where(account_id: @account.id, deleted_at: nil).where.not(user_role: "Owner")
    
    CSV.generate(headers: true) do |csv|
      csv << attributes
      unless @account_users.nil? && @account_users.blank?
        @account_users.each do |account_users|
          csv << [account_users.user.username, account_users.allocation_amt]
        end
      end
    end
  end

  def validate_file_type!
    # Check file type
    unless @payment_source_user_import.content_type.include?("excel")
      raise StandardError.new "Error file type"
      # flash.now[:error] = text("Error file type")
    end
  end

  def service_username_lookup(username)
    LdapAuthentication::UserLookup.new.call(username)
  end

  def username_database_lookup(username)
    User.find_by("LOWER(username) = ?", username.downcase)
  end

  def insert_payment_source_user!
    @header = CSV.open(@payment_source_user_import.path,&:readline)

    if @header.compact.eql?(REQUIRED_HEADERS)
      
      csv_table = CSV.table(@payment_source_user_import.path)
      if csv_table.count > 0
        CSV.foreach(@payment_source_user_import.path, headers: true, skip_lines: /^,*$/, header_converters: :symbol) do |row|
          @netid = row[:netid] || ""
          @quota = row[:quota] || 0
          @user = search_user(@netid)
          
          if !@user.nil? && !@user.blank? && (@quota == 0 || @quota.match(/\A-?+(?=.??\d)\d*\.?\d*\z/) )
            @old_account_user = AccountUser.find_by(account: @account, user: @user, deleted_at: nil)
            create_payment_source_user(@user, @account, @quota) if @old_account_user.nil? && @old_account_user.blank?
            LogEvent.log(@user, :create, @session_user) if @old_account_user.nil? && @old_account_user.blank?
            error_user_list(@netid) unless @old_account_user.nil? && @old_account_user.blank?
          else 
            error_user_list(@netid) unless @netid == ""
          end
        end
      end
    end 
    send_mail(@error_list, "Insert") if @error_list.count > 0 
  end

  def update_payment_source_user!
    @header = CSV.open(@payment_source_user_import.path,&:readline)

    @account_user_list = Hash.new 
    if @header.compact.eql?(REQUIRED_HEADERS)
      csv_table = CSV.table(@payment_source_user_import.path)
      if csv_table.count > 0
        CSV.foreach(@payment_source_user_import.path, headers: true, skip_lines: /^,*$/, header_converters: :symbol) do |row|
          @netid = row[:netid] || ""
          @quota = row[:quota] || 0
          
          @user = search_user(@netid)
        

          if !@user.nil? && !@user.blank? && (@quota == 0 || @quota.match(/\A-?+(?=.??\d)\d*\.?\d*\z/) )
            @account_user = AccountUser.find_by(account: @account, user: @user, deleted_at: nil)
            unless @account_user.nil? && @user.blank?
              h = {:allocation_amt => @quota, :id => @account_user.id} if !@account_user.user_role.eql?("Owner")
              @account_user_list[@account_user.id] = h if !@account_user.user_role.eql?("Owner")
              error_user_list(@netid) if @account_user.user_role.eql?("Owner")
            else 
              error_user_list(@netid) unless @netid == ""
            end
          else 
            error_user_list(@netid) unless @netid == ""
          end
        end
  
        unless @account_user_list.nil?
  
          auv = @account_user_list.values
          @account.assign_attributes(account_users_attributes: auv)
          unless @account.save
            raise StandardError.new "Error import"
          end
        end
      end
    end
    send_mail(@error_list, "Update") if @error_list.count > 0 
  end

  def save_pair(parent, myHash)
    myHash.each {|key, value|
      value.is_a?(Hash) ? save_pair(key, value) :
              puts("parent=#{parent.nil? ? 'none':parent}, (#{key}, #{value})")
    }
  end

  def search_user(username) 
    User.find_by("LOWER(username) = ?", username.downcase) unless username.blank?
  end

  def error_user_list(username)
    @error_list.push(username)
  end

  def create_payment_source_user(user, account, quota)
    @account_user = AccountUser.create_member(quota, user, "Purchaser", account, by: @session_user)
    @new_account_user = AccountUser.find_by(account: account, user: user, deleted_at: nil)
    # @new_account_user.allocation_amt = quota
    # unless @new_account_user.save
    #   raise StandardError.new "Error import"
    # end
  end

  def send_mail(user_list, type)
    # user_list.each { |x| puts x }   
    Notifier.send_payment_source_import_error_mail(@session_user, @account, user_list, type).deliver_later
    raise StandardError.new "The error list will send mail to your inbox"
  end
end
