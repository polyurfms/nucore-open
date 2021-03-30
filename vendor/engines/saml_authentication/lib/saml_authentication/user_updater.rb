# frozen_string_literal: true

require "saml_authentication/saml_attributes"

module SamlAuthentication

  class UserUpdater

    def initialize(skip_attributes: [], **_args)
      @skip_attributes = Array(skip_attributes)
    end

    def call(user, saml_response, _auth_value)
      attributes = SamlAttributes.new(saml_response).except(*@skip_attributes).merge(
        encrypted_password: nil,
        password_salt: nil,
      )

      @member_of = saml_response.raw_response.attributes.to_h.fetch('memberof')

      if @member_of.include?('polyu_staff_04AA') ||
        @member_of.include?('polyu_staff_04ACA') ||
        @member_of.include?('polyu_staff_ACA')
        attributes = attributes.merge(is_academic: true)
      else
        attributes = attributes.merge(is_academic: false)
      end

      #for UAT, do not overwrite user email when login
      if Settings.uat.email.present?
        if user.email.present?
          attributes['email'] = user.email
        end
      end

      user.update!(attributes)

      if user.sign_in_count == 0
        if user.user_type == 'Staff'
          user.update_to_internal_price_group!
        end
      end


    end

  end

end
