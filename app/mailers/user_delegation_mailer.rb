# frozen_string_literal: true

class UserDelegationMailer < ActionMailer::Base

    default from: Settings.email.from, content_type: "multipart/alternative"
  
    def notify(delegatee:, delegator:)
      @delegatee = delegatee
      @delegator = delegator
      send_nucore_mail @delegatee.email, text("views.user_delegation.subject", delegatee: @delegatee.username, delegator: @delegator.username)
    end
  
    def send_nucore_mail(to, subject)
      mail(subject: subject, to: to)
    end
  
  end
  