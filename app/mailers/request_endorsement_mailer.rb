# frozen_string_literal: true

class RequestEndorsementMailer < ActionMailer::Base


  default from: Settings.email.from, content_type: "multipart/alternative"

  def notify(to, requester, request_endorsement, first_name, last_name, expiry_date)
    @to = to
    @requester = requester
    @request_endorsement = request_endorsement
    @first_name = first_name || ""
    @last_name = last_name || ""
    @to_fullname = @first_name + " " + @last_name
    @dept_abbrev = requester.dept_abbrev.nil? ? " " : requester.dept_abbrev
    @request_fullname = requester.first_name + " " + requester.last_name + " [" + @dept_abbrev + "]"

    @requester_netID = @requester.username
    @requester_post_title = @requester.post_title.nil? ? " " : @requester.post_title
    @expiry_date = expiry_date

    send_nucore_mail @to, text("views.request_endorsements.subject", requester_name: @request_fullname)
  end

  def confirm_notify(to, request_endorsement, status)
    @to = to
    @first_name = request_endorsement.first_name || ""
    @last_name = request_endorsement.last_name || ""
    @supervisor_fullname = @first_name + " " + @last_name
    @status = status
    send_nucore_mail @to, text("views.confirm_request_endorsements.subject", supervisor_fullname: @supervisor_fullname, status: @status)
  end

  def remove_notify(to, requester, request_endorsement, first_name, last_name)
    @to = to
    @requester = requester
    @request_endorsement = request_endorsement
    @first_name = first_name || ""
    @last_name = last_name || ""
    @to_fullname = @first_name + " " + @last_name
    @request_fullname = requester.first_name + " " + requester.last_name
    send_nucore_mail @to, text("views.cancel_request_endorsements.subject", requester_name: @request_fullname)
  end

  def send_nucore_mail(to, subject)
    mail(subject: subject, to: to)
  end

end
