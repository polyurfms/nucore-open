class SupervisorCreator

  attr_reader :params, :error

  def self.update(user, last_name, first_name, email, updated_by)
    @user = user
    @supervisor = @user.supervisor
    if @user.supervisor.present?
      @supervisor.assign_attributes(last_name: last_name, first_name: first_name, email: email, updated_by: updated_by)
    else
      @supervisor = Supervisor.new(
          user_id: @user.id,
          last_name: last_name,
          first_name: first_name,
          email: email,
          created_by: updated_by,
          updated_by: updated_by
      )
    end

    @supervisor.save

  end

  def initialize(user, last_name, first_name, email)
    @user = user
    @last_name = last_name
    @first_name = first_name
    @email = email

    @supervisor = Supervisor.new(
        user_id: @user.id,
        last_name: @last_name,
        first_name: @first_name,
        email: @email,
        created_by: @user.id,
        updated_by: @user.id
    )
  end

  def save

    ActiveRecord::Base.transaction do

      if @supervisor.save
          @success = :default
          LogEvent.log(@supervisor, :create, @user, metadata: { last_name: @last_name, first_name: @first_name, email: @email })
      else
         #@input_amt = amt
          @error = "Failed to save supervisor"
          raise ActiveRecord::Rollback
      end
    end
  end

  def supervisor_params
      @params.require(:supervisor).permit(:user_id, :last_name, :first_name, :email)
  end


end
