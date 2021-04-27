class SupervisorCreator

  attr_reader :params, :error

  def initialize(user_id, last_name, first_name, email)
    @user_id = user_id
    @last_name = last_name
    @first_name = first_name
    @email = email
  end

  def save
      @supervisor = Supervisor.new(
          user_id: @user_id,
          last_name: @last_name,
          first_name: @first_name,
          email: @email
      )

    ActiveRecord::Base.transaction do

      if @supervisor.save
          @success = :default
      else
         #@input_amt = amt
          @error = "Failed to create funding request"
          raise ActiveRecord::Rollback
      end
    end
  end

  def supervisor_params
      @params.require(:supervisor).permit(:user_id, :last_name, :first_name, :email)
  end


end
