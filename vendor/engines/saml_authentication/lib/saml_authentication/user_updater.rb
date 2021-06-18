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

      @is_academic = false;

      if Settings.saml.academic_member.present?
        @cat = Settings.saml.academic_member;
        @cat.each do |v|
          if @member_of.include?(v)
            @is_academic = true;
          end
        end
        attributes = attributes.merge(is_academic: @is_academic)
      end

      #for UAT, do not overwrite user email when login
      if Settings.uat.email.present?
        if user.email.present?
          attributes['email'] = user.email
        end
      end

      #in case user do not have first name, set it to empty space to pass validation
      unless attributes.key?("first_name")
        attributes["first_name"] = " "
      end

      user.update!(attributes)

      if user.sign_in_count == 0
        if user.user_type == 'Staff' || user.user_type == 'Student'
          user.update_to_internal_price_group!
        else
          user.update_to_base_external_group!
        end
      end


    end

  end

end
