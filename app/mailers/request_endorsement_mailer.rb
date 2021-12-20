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

  def confirm_notify(to, supervisor, requester, status)
    @to = to
    @r_first_name = requester.first_name || ""
    @r_last_name = requester.last_name || ""
    @requester_fullname = @r_first_name + " " + @r_last_name
    @s_first_name = supervisor.first_name || ""
    @s_last_name = supervisor.last_name || ""
    @supervisor_fullname = @s_first_name + " " + @s_last_name
    @status = status
    @cc = supervisor.email
    send_nucore_mail @to, text("views.confirm_request_endorsements.subject", status: @status), @cc
  end

  def remove_notify(to, requester, supervisor)
    @to = to
    @r_first_name = requester.first_name || ""
    @r_last_name = requester.last_name || ""
    @requester_fullname = @r_first_name + " " + @r_last_name
    @s_first_name = supervisor.first_name || ""
    @s_last_name = supervisor.last_name || ""
    @supervisor_fullname = @s_first_name + " " + @s_last_name
    @cc = requester.email
    @dept_abbrev = requester.dept_abbrev.nil? ? " " : requester.dept_abbrev

    send_nucore_mail @to, text("views.remove_request_endorsements.subject", requester_fullname: @requester_fullname + " [" + @dept_abbrev + "]"), @cc
  end

  def send_nucore_mail(to, subject, cc = "")
    mail(subject: subject, to: to) if cc.blank?
    mail(subject: subject, to: to, cc: cc) unless cc.blank?
  end

end
