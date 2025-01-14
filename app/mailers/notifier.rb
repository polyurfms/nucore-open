# frozen_string_literal: true

class Notifier < ActionMailer::Base

  include DateHelper
  add_template_helper ApplicationHelper
  add_template_helper ViewHookHelper

  default from: Settings.email.from, content_type: "multipart/alternative"

  # Welcome user, login credentials
  def new_user(user:, password:)
    @user = user
    @password = password
    send_nucore_mail @user.email, text("views.notifier.new_user.subject")
  end

  # Changes to the user affecting the PI or department will alert their
  # PI, the Dept Admins, and Lab Manager.
  def user_update(args)
    @user = args[:user]
    @account = args[:account]
    @created_by = args[:created_by]
    send_nucore_mail @account.owner.user.email, text("views.notifier.user_update.subject")
  end

  # Any changes to the financial accounts will alert the PI(s), admin(s)
  # when it is not them making the change. Adding someone to any role of a
  # financial account as well. Roles: Order, Admin, PI.
  def account_update(args)
    @user = args[:user]
    @account = args[:account]
    send_nucore_mail args[:user].email, text("views.notifier.account_update.subject")
  end

  def review_orders(user:, accounts:, facility: Facility.cross_facility)
    @user = user
    @accounts = accounts
    @facility = facility
    @accounts_grouped_by_owner = accounts.group_by(&:owner_user)
    send_nucore_mail @user.email, text("views.notifier.review_orders.subject", abbreviation: @facility.abbreviation)
  end

  # Billing sends out the statement for the month. Appropriate users get
  # their version of usage.
  # args = :user, :account, :facility
  def statement(args)
    @user = args[:user]
    @facility = args[:facility]
    @account = args[:account]
    @statement = args[:statement]
    attach_statement_pdf
    #send_nucore_mail args[:user].email, text("views.notifier.statement.subject", facility: @facility)
    send_nucore_mail_cc Settings.statement_pdf.email_to, text("views.notifier.statement.subject", facility: @facility)
  end

  def order_detail_status_changed(order_detail)
    @order_detail = order_detail
    facility = order_detail.facility.abbreviation
    status = order_detail.order_status.name
    mail(
      to: order_detail.order.user.email,
      subject: text("views.notifier.order_detail_status_changed.subject", facility: facility, status: status)
    )
  end

  def send_payment_source_import_error_mail(user, account, error_user_list, status)
    @upload_csv_user = user
    @error_user_list = error_user_list
    account = account
    status = status
    mail(
      to: user.email,
      subject: text("views.notifier.send_payment_source_import_error_mail.subject", account: account, status: status)
    )
  end

  private

  def attach_statement_pdf
    attachments[statement_pdf.filename] = {
      mime_type: "application/pdf",
      content: statement_pdf.render,
    }
  end

  def statement_pdf
    @statement_pdf ||= StatementPdfFactory.instance(@statement)
  end

  def send_nucore_mail(to, subject, template_name = nil)
    mail(subject: subject, to: to, template_name: template_name)
  end

  def send_nucore_mail_cc(to, subject, template_name = nil)

    mail(subject: subject,
      to: to,
      cc: Settings.statement_pdf.email_cc,
      template_name: template_name)
  end

end
