# frozen_string_literal: true

class UserSummaryController < ApplicationController

  before_action :authenticate_user!

  load_resource :user
  layout -> { modal? ? false : "application" }

  def new
    puts "===================== user summary"
    puts "xxxx #{@user}"
    render layout: false
  end


  private

  def helpers
    ActionController::Base.helpers
  end

  def modal?
    request.xhr?
  end
  helper_method :modal?

end
