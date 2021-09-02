# frozen_string_literal: true

class RequsetEndorsementMailer < ActionMailer::Base

  
  default from: Settings.email.from, content_type: "multipart/alternative"

  def notify(to, requester, request_endorsement)
    @to = to
    @requester = requester
    @request_endorsement = request_endorsement 
    @to_fullname = to.first_name + " " + to.last_name
    @request_fullname = requester.first_name + " " + requester.last_name
    send_nucore_mail @to.email, text("views.request_endorsements.subject", requester_name: @request_fullname)
  end

  def confirm_notify(to, supervisor, status)
    @to = to
    @supervisor = supervisor
    @supervisor_fullname = @supervisor.first_name + " " + @supervisor.last_name
    @status = status
    send_nucore_mail @to, text("views.confirm_request_endorsements.subject", supervisor_fullname: @supervisor_fullname, status: @status)
  end


  def send_nucore_mail(to, subject)
    mail(subject: subject, to: to)
  end

end
