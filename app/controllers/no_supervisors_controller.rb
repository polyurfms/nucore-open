
class NoSupervisorsController < ApplicationController

    include AZHelper

    def index
      if session[:had_supervisor] == 1 || session[:had_supervisor].blank? || session_user.administrator?
        redirect_to '/facilities'
      end
    end
    
  end
  