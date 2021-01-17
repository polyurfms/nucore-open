# frozen_string_literal: true

class PaymentSourceRequestMailer < ActionMailer::Base

  default from: Settings.email.from, content_type: "multipart/alternative"

  def notify(user:, request_user:, account:)
    @user = user
    @request_user = request_user
    @account = account
    send_nucore_mail @user.email, text("views.payment_source_requests.subject", requestUser: @request_user.username, accountNumber: @account.account_number)
  end
  
  def send_nucore_mail(to, subject)
    mail(subject: subject, to: to)
  end

end
  